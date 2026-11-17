defmodule OrcavoiceWeb.ChatroomJSON do
  alias Orcavoice.Chat.Chatroom

  def index(%{chatrooms: rooms, next_cursor: next_cursor}) do
    %{data: Enum.map(rooms, &data/1), next_cursor: next_cursor}
  end

  def show(%{chatroom: room}), do: %{data: data(room)}

  def data(%Chatroom{} = room) do
    %{
      id: room.id,
      name: room.name,
      slug: room.slug,
      description: room.description,
      is_private: room.is_private,
      max_participants: room.max_participants,
      owner_id: room.owner_id,
      inserted_at: room.inserted_at,
      updated_at: room.updated_at
    }
  end
end
