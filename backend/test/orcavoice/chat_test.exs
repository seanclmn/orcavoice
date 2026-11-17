defmodule Orcavoice.ChatTest do
  use Orcavoice.DataCase, async: true

  import Orcavoice.AccountsFixtures
  import Orcavoice.ChatFixtures

  alias Orcavoice.Accounts
  alias Orcavoice.Chat
  alias Orcavoice.Chat.Chatroom

  describe "create_chatroom/2" do
    test "creates a room owned by the user, generating a slug" do
      owner = user_fixture()

      assert {:ok, %Chatroom{} = room} = Chat.create_chatroom(owner, %{name: "Late Night Talk!"})
      assert room.slug == "late-night-talk"
      assert room.owner_id == owner.id
      assert room.is_private == false
      assert room.max_participants == 50
      assert Chat.owner?(room, owner)
    end

    test "requires a name" do
      assert {:error, changeset} = Chat.create_chatroom(user_fixture(), %{})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "slug must be unique" do
      chatroom_fixture(nil, %{name: "Lobby"})
      assert {:error, changeset} = Chat.create_chatroom(user_fixture(), %{name: "lobby"})
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "validates max_participants range" do
      assert {:error, changeset} =
               Chat.create_chatroom(user_fixture(), %{name: "Big", max_participants: 0})

      assert errors_on(changeset).max_participants != []
    end
  end

  describe "list_public_chatrooms/1" do
    test "excludes private rooms and paginates by cursor" do
      owner = user_fixture()
      rooms = for i <- 1..5, do: chatroom_fixture(owner, %{name: "Public #{i}"})
      _private = chatroom_fixture(owner, %{name: "Secret", is_private: true})

      all = Chat.list_public_chatrooms()
      assert length(all) == 5
      assert Enum.sort(Enum.map(all, & &1.id)) == Enum.sort(Enum.map(rooms, & &1.id))

      page1 = Chat.list_public_chatrooms(limit: 2)
      page2 = Chat.list_public_chatrooms(limit: 2, after: List.last(page1))
      page3 = Chat.list_public_chatrooms(limit: 2, after: List.last(page2))

      assert Enum.map(page1 ++ page2 ++ page3, & &1.id) == Enum.map(all, & &1.id)
    end
  end

  test "deleting the owner keeps the room with no owner" do
    owner = user_fixture()
    room = chatroom_fixture(owner)

    {:ok, _} = Accounts.delete_user(owner)

    assert Chat.get_chatroom!(room.id).owner_id == nil
  end
end
