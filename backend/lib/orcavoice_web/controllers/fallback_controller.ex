defmodule OrcavoiceWeb.FallbackController do
  @moduledoc "Turns `{:error, _}` results from controller actions into JSON error responses."

  use OrcavoiceWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: OrcavoiceWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, status}) when status in [:not_found, :forbidden, :bad_request] do
    conn
    |> put_status(status)
    |> put_view(json: OrcavoiceWeb.ErrorJSON)
    |> render(Plug.Conn.Status.code(status) |> Integer.to_string() |> String.to_atom())
  end
end
