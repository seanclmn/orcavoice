defmodule OrcavoiceWeb.Cursor do
  @moduledoc """
  Opaque pagination cursors for keyset pagination.

  A cursor encodes the `{inserted_at, id}` of the last item on a page.
  Clients should treat it as an opaque string and pass it back unchanged.
  """

  def encode(%{inserted_at: %DateTime{} = ts, id: id}) do
    Base.url_encode64("#{DateTime.to_unix(ts, :microsecond)}:#{id}", padding: false)
  end

  def decode(nil), do: {:ok, nil}
  def decode(""), do: {:ok, nil}

  def decode(cursor) when is_binary(cursor) do
    with {:ok, raw} <- Base.url_decode64(cursor, padding: false),
         [ts_str, id_str] <- String.split(raw, ":", parts: 2),
         {ts_int, ""} <- Integer.parse(ts_str),
         {:ok, ts} <- DateTime.from_unix(ts_int, :microsecond),
         {:ok, id} <- Ecto.UUID.cast(id_str) do
      # Columns are second precision (:utc_datetime), so match that here.
      {:ok, {DateTime.truncate(ts, :second), id}}
    else
      _ -> {:error, :bad_request}
    end
  end

  def decode(_), do: {:error, :bad_request}
end
