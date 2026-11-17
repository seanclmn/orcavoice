defmodule OrcavoiceWeb.CacheBodyReader do
  @moduledoc """
  Keeps the raw request body for paths that need to verify a signature over
  it (LiveKit webhooks). Other requests are read normally so we don't hold
  extra copies of every body in memory.
  """

  @raw_body_paths ["/api/livekit/webhook"]

  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      if conn.request_path in @raw_body_paths do
        {:ok, body, Plug.Conn.put_private(conn, :raw_body, body)}
      else
        {:ok, body, conn}
      end
    end
  end
end
