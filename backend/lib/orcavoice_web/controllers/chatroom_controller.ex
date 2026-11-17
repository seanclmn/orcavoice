defmodule OrcavoiceWeb.ChatroomController do
  use OrcavoiceWeb, :controller

  alias Orcavoice.Chat
  alias Orcavoice.LiveKit
  alias OrcavoiceWeb.Cursor

  action_fallback OrcavoiceWeb.FallbackController

  @room_fields ~w(name slug description is_private max_participants)

  # GET /api/chatrooms?limit=20&cursor=...
  def index(conn, params) do
    with {:ok, limit} <- parse_limit(params["limit"]),
         {:ok, cursor} <- Cursor.decode(params["cursor"]) do
      rooms = Chat.list_public_chatrooms(limit: limit, after: cursor)

      next_cursor =
        if length(rooms) == limit, do: rooms |> List.last() |> Cursor.encode(), else: nil

      render(conn, :index, chatrooms: rooms, next_cursor: next_cursor)
    end
  end

  # GET /api/chatrooms/occupancy?ids=id1,id2,...
  # Live participant counts, kept separate from room metadata so clients can
  # poll it often while caching the room list.
  @max_occupancy_ids 100
  def occupancy(conn, params) do
    ids =
      (params["ids"] || "")
      |> String.split(",", trim: true)
      |> Enum.uniq()

    if length(ids) > @max_occupancy_ids do
      {:error, :bad_request}
    else
      json(conn, %{data: Chat.Occupancy.counts(ids)})
    end
  end

  # GET /api/chatrooms/:id
  # Private rooms are reachable by id/slug (like an unlisted link); they are
  # only hidden from listings. Revisit once room membership exists.
  def show(conn, %{"id" => id}) do
    with %{} = room <- Chat.get_chatroom(id) || {:error, :not_found} do
      render(conn, :show, chatroom: room)
    end
  end

  # GET /api/chatrooms/slug/:slug
  def show_by_slug(conn, %{"slug" => slug}) do
    with %{} = room <- Chat.get_chatroom_by_slug(slug) || {:error, :not_found} do
      render(conn, :show, chatroom: room)
    end
  end

  # POST /api/chatrooms
  def create(conn, params) do
    with {:ok, room} <-
           Chat.create_chatroom(conn.assigns.current_user, Map.take(params, @room_fields)) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/chatrooms/#{room.id}")
      |> render(:show, chatroom: room)
    end
  end

  # POST /api/chatrooms/:id/token
  # Credentials for the current user to join the room's voice channel.
  # Everyone joins as a listener; Chat.Speakers grants speaking rights.
  def token(conn, %{"id" => id}) do
    with %{} = room <- Chat.get_chatroom(id) || {:error, :not_found} do
      user = conn.assigns.current_user
      room_name = LiveKit.room_name(room)

      json(conn, %{
        data: %{
          token: LiveKit.join_token(room_name, user.id, user.display_name || user.username),
          url: LiveKit.public_url(),
          room_name: room_name,
          speaker_limit: Chat.Speakers.limit()
        }
      })
    end
  end

  # PATCH /api/chatrooms/:id
  def update(conn, %{"id" => id} = params) do
    with {:ok, room} <- fetch_owned_room(conn, id),
         {:ok, room} <- Chat.update_chatroom(room, Map.take(params, @room_fields)) do
      render(conn, :show, chatroom: room)
    end
  end

  # DELETE /api/chatrooms/:id
  def delete(conn, %{"id" => id}) do
    with {:ok, room} <- fetch_owned_room(conn, id),
         {:ok, _} <- Chat.delete_chatroom(room) do
      send_resp(conn, :no_content, "")
    end
  end

  defp fetch_owned_room(conn, id) do
    case Chat.get_chatroom(id) do
      nil ->
        {:error, :not_found}

      room ->
        if Chat.owner?(room, conn.assigns.current_user),
          do: {:ok, room},
          else: {:error, :forbidden}
    end
  end

  @max_limit 100
  defp parse_limit(nil), do: {:ok, 50}

  defp parse_limit(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> {:ok, min(n, @max_limit)}
      _ -> {:error, :bad_request}
    end
  end
end
