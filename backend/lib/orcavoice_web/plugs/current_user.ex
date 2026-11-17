defmodule OrcavoiceWeb.Plugs.CurrentUser do
  @moduledoc """
  PLACEHOLDER authentication until real auth (sessions/tokens) exists.

  When `config :orcavoice, :header_auth, true` is set (dev/test only), the
  request is treated as coming from the user whose id is in the `x-user-id`
  header. Anyone can send any id, so this must never be enabled in production.
  When the flag is off, no request is ever authenticated.

  Replace `fetch_current_user/2` with real token verification later; the rest
  of the app only depends on `conn.assigns.current_user`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, render: 3]

  alias Orcavoice.Accounts

  def fetch_current_user(conn, _opts) do
    with true <- Application.get_env(:orcavoice, :header_auth, false),
         [user_id | _] <- get_req_header(conn, "x-user-id"),
         %{} = user <- Accounts.get_user(user_id) do
      assign(conn, :current_user, user)
    else
      _ -> assign(conn, :current_user, nil)
    end
  end

  def require_user(%{assigns: %{current_user: %{}}} = conn, _opts), do: conn

  def require_user(conn, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: OrcavoiceWeb.ErrorJSON)
    |> render(:"401", %{})
    |> halt()
  end
end
