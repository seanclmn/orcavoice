defmodule Orcavoice.ChatFixtures do
  import Orcavoice.AccountsFixtures

  def chatroom_fixture(owner \\ nil, attrs \\ %{}) do
    owner = owner || user_fixture()

    {:ok, chatroom} =
      Orcavoice.Chat.create_chatroom(
        owner,
        Enum.into(attrs, %{name: "Room #{System.unique_integer([:positive])}"})
      )

    chatroom
  end
end
