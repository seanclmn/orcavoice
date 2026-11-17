defmodule Orcavoice.Chat do
  @moduledoc """
  Chatrooms (voice rooms).

  Postgres holds the durable room metadata only. Live state such as who is
  currently connected belongs in Phoenix.Presence / LiveKit, not here.
  """

  import Ecto.Query, warn: false

  alias Orcavoice.Repo
  alias Orcavoice.Accounts.User
  alias Orcavoice.Chat.Chatroom

  @default_page_size 50
  @max_page_size 100

  @doc """
  Lists public chatrooms, newest first, using keyset pagination.

  Pass the last room you received (or its `{inserted_at, id}`) as `:after`
  to get the next page. This stays fast on large tables, where OFFSET would not.
  """
  def list_public_chatrooms(opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_page_size) |> min(@max_page_size)

    Chatroom
    |> where([c], c.is_private == false)
    |> after_cursor(Keyword.get(opts, :after))
    |> order_by([c], desc: c.inserted_at, desc: c.id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp after_cursor(query, nil), do: query

  defp after_cursor(query, %Chatroom{inserted_at: ts, id: id}), do: after_cursor(query, {ts, id})

  defp after_cursor(query, {ts, id}) do
    where(query, [c], c.inserted_at < ^ts or (c.inserted_at == ^ts and c.id < ^id))
  end

  @doc """
  Rooms owned by a user, newest first.

  Pass `include_private: false` when someone other than the owner is looking.
  """
  def list_chatrooms_owned_by(%User{id: owner_id}, opts \\ []) do
    Chatroom
    |> where([c], c.owner_id == ^owner_id)
    |> then(fn q ->
      if Keyword.get(opts, :include_private, true), do: q, else: where(q, [c], not c.is_private)
    end)
    |> order_by([c], desc: c.inserted_at, desc: c.id)
    |> Repo.all()
  end

  def get_chatroom!(id), do: Repo.get!(Chatroom, id)

  @doc "Returns the room, or nil if not found or `id` is not a valid UUID."
  def get_chatroom(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Chatroom, uuid)
      :error -> nil
    end
  end

  def get_chatroom_by_slug(slug) when is_binary(slug), do: Repo.get_by(Chatroom, slug: slug)

  def create_chatroom(%User{} = owner, attrs) do
    %Chatroom{owner_id: owner.id}
    |> Chatroom.changeset(attrs)
    |> Repo.insert()
  end

  def update_chatroom(%Chatroom{} = chatroom, attrs) do
    chatroom
    |> Chatroom.changeset(attrs)
    |> Repo.update()
  end

  def delete_chatroom(%Chatroom{} = chatroom), do: Repo.delete(chatroom)

  def change_chatroom(%Chatroom{} = chatroom, attrs \\ %{}),
    do: Chatroom.changeset(chatroom, attrs)

  def owner?(%Chatroom{owner_id: owner_id}, %User{id: user_id}), do: owner_id == user_id
end
