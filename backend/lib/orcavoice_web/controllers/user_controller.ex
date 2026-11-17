defmodule OrcavoiceWeb.UserController do
  use OrcavoiceWeb, :controller

  alias Orcavoice.Accounts
  alias Orcavoice.Chat

  action_fallback OrcavoiceWeb.FallbackController

  @user_fields ~w(username email display_name avatar_url)
  @profile_fields ~w(display_name avatar_url)

  # POST /api/users
  def create(conn, params) do
    with {:ok, user} <- Accounts.create_user(Map.take(params, @user_fields)) do
      conn
      |> put_status(:created)
      |> render(:me, user: user)
    end
  end

  # GET /api/users/:id
  def show(conn, %{"id" => id}) do
    with %{} = user <- Accounts.get_user(id) || {:error, :not_found} do
      render(conn, :show, user: user)
    end
  end

  # GET /api/users/:id/chatrooms
  def chatrooms(conn, %{"id" => id}) do
    with %{} = user <- Accounts.get_user(id) || {:error, :not_found} do
      viewer = conn.assigns.current_user
      is_self = viewer != nil and viewer.id == user.id
      rooms = Chat.list_chatrooms_owned_by(user, include_private: is_self)

      conn
      |> put_view(json: OrcavoiceWeb.ChatroomJSON)
      |> render(:index, chatrooms: rooms, next_cursor: nil)
    end
  end

  # GET /api/me
  def me(conn, _params) do
    render(conn, :me, user: conn.assigns.current_user)
  end

  # PATCH /api/me
  def update_me(conn, params) do
    with {:ok, user} <-
           Accounts.update_user(conn.assigns.current_user, Map.take(params, @profile_fields)) do
      render(conn, :me, user: user)
    end
  end
end
