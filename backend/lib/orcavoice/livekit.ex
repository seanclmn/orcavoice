defmodule Orcavoice.LiveKit do
  @moduledoc """
  Minimal client for LiveKit's server API (Twirp over HTTP/JSON), plus access
  token minting and webhook verification.

  Each chatroom maps to a LiveKit room named after the chatroom's id.

  Configured via:

      config :orcavoice, Orcavoice.LiveKit,
        url: "http://localhost:7880",        # server API, reached by the backend
        public_url: "ws://localhost:7880",   # what browsers connect to
        api_key: "...",
        api_secret: "..."
  """

  @server_token_ttl 60
  @join_token_ttl 10 * 60

  @doc "LiveKit room name for a chatroom."
  def room_name(%{id: id}), do: id

  def public_url, do: config()[:public_url]

  ## Server API

  @doc """
  Lists active LiveKit rooms (all of them when `names` is empty).

  Returns `{:ok, %{room_name => participant_count}}`.
  """
  def list_room_counts(names \\ []) do
    with {:ok, body} <- twirp("ListRooms", %{names: names}, %{roomList: true}) do
      {:ok,
       for room <- Map.get(body, "rooms", []), into: %{} do
         {room["name"], field(room, "num_participants", "numParticipants", 0)}
       end}
    end
  end

  @doc """
  Lists participants in a room as maps with `:identity`, `:joined_at` (unix
  seconds), `:can_publish` and `:kind`.
  """
  def list_participants(room) do
    with {:ok, body} <- twirp("ListParticipants", %{room: room}, %{roomAdmin: true, room: room}) do
      {:ok, Enum.map(Map.get(body, "participants", []), &normalize_participant/1)}
    end
  end

  @doc """
  Sets whether a participant may publish (speak). Listeners can still hear.

  Speakers may only publish their microphone; this is a voice app.
  """
  def set_can_publish(room, identity, can_publish?) do
    permission = %{
      can_subscribe: true,
      can_publish: can_publish?,
      can_publish_data: false,
      can_publish_sources: if(can_publish?, do: ["MICROPHONE"], else: [])
    }

    payload = %{room: room, identity: identity, permission: permission}

    with {:ok, _} <- twirp("UpdateParticipant", payload, %{roomAdmin: true, room: room}) do
      :ok
    end
  end

  defp normalize_participant(p) do
    permission = p["permission"] || %{}

    %{
      identity: p["identity"],
      joined_at: to_int(field(p, "joined_at", "joinedAt", 0)),
      can_publish: field(permission, "can_publish", "canPublish", false),
      kind: p["kind"] || "STANDARD"
    }
  end

  # proto3 JSON omits zero values and may use either field casing.
  defp field(map, snake, camel, default), do: map[snake] || map[camel] || default

  # int64 fields are encoded as strings in proto3 JSON.
  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)

  defp twirp(method, payload, video_grant) do
    config = config()

    Req.post(
      "#{config[:url]}/twirp/livekit.RoomService/#{method}",
      json: payload,
      auth: {:bearer, server_token(config, video_grant)},
      receive_timeout: 5_000,
      retry: false
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Server API calls are authenticated with a short-lived HS256 JWT signed by
  # the API secret, carrying the needed "video" grants.
  defp server_token(config, video_grant) do
    now = System.system_time(:second)

    sign_jwt(
      %{iss: config[:api_key], nbf: now - 5, exp: now + @server_token_ttl, video: video_grant},
      config[:api_secret]
    )
  end

  ## Client access tokens

  @doc """
  Mints a token that lets a browser join `room` as `identity`.

  Everyone joins unable to publish. `Orcavoice.Chat.Speakers` grants speaking
  rights server-side, so the speaker limit can't be bypassed by the client.
  The TTL only bounds the initial connect; LiveKit refreshes it afterwards.
  """
  def join_token(room, identity, display_name) do
    config = config()
    now = System.system_time(:second)

    sign_jwt(
      %{
        iss: config[:api_key],
        sub: identity,
        name: display_name,
        nbf: now - 5,
        exp: now + @join_token_ttl,
        video: %{
          room: room,
          roomJoin: true,
          canSubscribe: true,
          canPublish: false,
          canPublishData: false
        }
      },
      config[:api_secret]
    )
  end

  ## Webhooks

  @doc """
  Verifies a LiveKit webhook and decodes its event.

  LiveKit sends a JWT in the Authorization header, signed with the API secret,
  whose `sha256` claim is the base64 SHA-256 of the raw request body.
  """
  def verify_webhook(raw_body, auth_header) when is_binary(raw_body) and is_binary(auth_header) do
    config = config()
    token = String.replace_prefix(auth_header, "Bearer ", "")

    with {:ok, claims} <- verify_jwt(token, config[:api_secret]),
         true <- claims["iss"] == config[:api_key] || {:error, :bad_issuer},
         true <-
           Plug.Crypto.secure_compare(
             claims["sha256"] || "",
             Base.encode64(:crypto.hash(:sha256, raw_body))
           ) || {:error, :body_mismatch},
         {:ok, event} <- Jason.decode(raw_body) do
      {:ok, event}
    end
  end

  def verify_webhook(_, _), do: {:error, :unauthorized}

  ## JWT (HS256)

  @doc false
  def sign_jwt(claims, secret) do
    signing_input = encode_segment(%{alg: "HS256", typ: "JWT"}) <> "." <> encode_segment(claims)
    signing_input <> "." <> b64(:crypto.mac(:hmac, :sha256, secret, signing_input))
  end

  defp verify_jwt(token, secret) do
    with [header, payload, signature] <- String.split(token, "."),
         expected = b64(:crypto.mac(:hmac, :sha256, secret, header <> "." <> payload)),
         true <- Plug.Crypto.secure_compare(signature, expected) || {:error, :bad_signature},
         {:ok, json} <- Base.url_decode64(payload, padding: false),
         {:ok, claims} <- Jason.decode(json),
         :ok <- check_time(claims) do
      {:ok, claims}
    else
      {:error, _} = error -> error
      _ -> {:error, :malformed_token}
    end
  end

  # Small leeway for clock skew between LiveKit and this node.
  @leeway 30
  defp check_time(claims) do
    now = System.system_time(:second)

    cond do
      is_integer(claims["exp"]) and claims["exp"] + @leeway < now -> {:error, :expired}
      is_integer(claims["nbf"]) and claims["nbf"] - @leeway > now -> {:error, :not_yet_valid}
      true -> :ok
    end
  end

  defp encode_segment(map), do: map |> Jason.encode!() |> b64()
  defp b64(bin), do: Base.url_encode64(bin, padding: false)

  defp config, do: Application.fetch_env!(:orcavoice, __MODULE__)
end
