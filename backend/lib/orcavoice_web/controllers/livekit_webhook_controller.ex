defmodule OrcavoiceWeb.LiveKitWebhookController do
  @moduledoc "Receives LiveKit webhooks (configured in livekit/livekit.yaml)."

  use OrcavoiceWeb, :controller

  require Logger

  alias Orcavoice.Chat.Speakers

  @membership_events ~w(participant_joined participant_left participant_connection_aborted)

  # POST /api/livekit/webhook
  def create(conn, _params) do
    {raw_body, conn} = raw_body(conn)
    auth = conn |> get_req_header("authorization") |> List.first()

    case Orcavoice.LiveKit.verify_webhook(raw_body, auth) do
      {:ok, %{"event" => event, "room" => %{"name" => room}}} when event in @membership_events ->
        Speakers.reconcile(room)
        send_resp(conn, :ok, "")

      {:ok, _other_event} ->
        send_resp(conn, :ok, "")

      {:error, reason} ->
        Logger.warning("Rejected LiveKit webhook: #{inspect(reason)}")
        send_resp(conn, :unauthorized, "")
    end
  end

  # Plug.Parsers caches the body (CacheBodyReader) when it parses it as JSON;
  # otherwise it is still unread and we read it here.
  defp raw_body(%{private: %{raw_body: body}} = conn), do: {body, conn}

  defp raw_body(conn) do
    case read_body(conn, length: 1_000_000) do
      {:ok, body, conn} -> {body, conn}
      _ -> {"", conn}
    end
  end
end
