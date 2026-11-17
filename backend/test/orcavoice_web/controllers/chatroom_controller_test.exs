defmodule OrcavoiceWeb.ChatroomControllerTest do
  use OrcavoiceWeb.ConnCase, async: true

  import Orcavoice.AccountsFixtures
  import Orcavoice.ChatFixtures

  defp as(conn, user), do: put_req_header(conn, "x-user-id", user.id)

  describe "GET /api/chatrooms" do
    test "lists public rooms with cursor pagination", %{conn: conn} do
      owner = user_fixture()
      for i <- 1..5, do: chatroom_fixture(owner, %{name: "Room #{i}"})
      chatroom_fixture(owner, %{name: "Secret", is_private: true})

      page1 = conn |> get(~p"/api/chatrooms?limit=2") |> json_response(200)
      assert length(page1["data"]) == 2
      assert is_binary(page1["next_cursor"])

      page2 =
        conn
        |> get(~p"/api/chatrooms?limit=2&cursor=#{page1["next_cursor"]}")
        |> json_response(200)

      page3 =
        conn
        |> get(~p"/api/chatrooms?limit=2&cursor=#{page2["next_cursor"]}")
        |> json_response(200)

      assert length(page3["data"]) == 1
      assert page3["next_cursor"] == nil

      names = Enum.map(page1["data"] ++ page2["data"] ++ page3["data"], & &1["name"])
      assert Enum.sort(names) == Enum.map(1..5, &"Room #{&1}")
    end

    test "rejects bad params", %{conn: conn} do
      assert json_response(get(conn, ~p"/api/chatrooms?limit=abc"), 400)
      assert json_response(get(conn, ~p"/api/chatrooms?cursor=garbage"), 400)
    end
  end

  describe "GET /api/chatrooms/:id and /slug/:slug" do
    test "returns the room", %{conn: conn} do
      room = chatroom_fixture(nil, %{name: "The Pod"})

      assert json_response(get(conn, ~p"/api/chatrooms/#{room.id}"), 200)["data"]["slug"] ==
               "the-pod"

      assert json_response(get(conn, ~p"/api/chatrooms/slug/the-pod"), 200)["data"]["id"] ==
               room.id
    end

    test "404s when missing", %{conn: conn} do
      assert json_response(get(conn, ~p"/api/chatrooms/#{Ecto.UUID.generate()}"), 404)
      assert json_response(get(conn, ~p"/api/chatrooms/slug/nope"), 404)
    end
  end

  describe "POST /api/chatrooms" do
    test "creates a room owned by the current user", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> as(user)
        |> post(~p"/api/chatrooms", %{name: "Deep Sea", owner_id: Ecto.UUID.generate()})

      data = json_response(conn, 201)["data"]
      assert data["owner_id"] == user.id
      assert data["slug"] == "deep-sea"
    end

    test "requires a user", %{conn: conn} do
      assert json_response(post(conn, ~p"/api/chatrooms", %{name: "x"}), 401)
    end

    test "returns validation errors", %{conn: conn} do
      conn = conn |> as(user_fixture()) |> post(~p"/api/chatrooms", %{name: ""})
      assert json_response(conn, 422)["errors"]["name"]
    end
  end

  describe "PATCH/DELETE /api/chatrooms/:id" do
    setup do
      owner = user_fixture()
      %{owner: owner, room: chatroom_fixture(owner)}
    end

    test "owner can update and delete", %{conn: conn, owner: owner, room: room} do
      conn1 = conn |> as(owner) |> patch(~p"/api/chatrooms/#{room.id}", %{description: "hi"})
      assert json_response(conn1, 200)["data"]["description"] == "hi"

      conn2 = conn |> as(owner) |> delete(~p"/api/chatrooms/#{room.id}")
      assert response(conn2, 204)
      assert json_response(get(conn, ~p"/api/chatrooms/#{room.id}"), 404)
    end

    test "non-owner is forbidden", %{conn: conn, room: room} do
      other = user_fixture()

      assert json_response(
               conn |> as(other) |> patch(~p"/api/chatrooms/#{room.id}", %{name: "mine"}),
               403
             )

      assert json_response(conn |> as(other) |> delete(~p"/api/chatrooms/#{room.id}"), 403)
    end
  end
end
