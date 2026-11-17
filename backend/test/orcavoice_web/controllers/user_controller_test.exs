defmodule OrcavoiceWeb.UserControllerTest do
  use OrcavoiceWeb.ConnCase, async: true

  import Orcavoice.AccountsFixtures
  import Orcavoice.ChatFixtures

  defp as(conn, user), do: put_req_header(conn, "x-user-id", user.id)

  describe "POST /api/users" do
    test "creates a user and returns private fields", %{conn: conn} do
      conn = post(conn, ~p"/api/users", %{username: "orca", email: "orca@example.com"})

      assert %{"id" => _, "username" => "orca", "email" => "orca@example.com"} =
               json_response(conn, 201)["data"]
    end

    test "returns validation errors", %{conn: conn} do
      conn = post(conn, ~p"/api/users", %{username: "x"})
      errors = json_response(conn, 422)["errors"]
      assert errors["email"] == ["can't be blank"]
      assert [_ | _] = errors["username"]
    end
  end

  describe "GET /api/users/:id" do
    test "returns the public profile without email", %{conn: conn} do
      user = user_fixture()
      data = conn |> get(~p"/api/users/#{user.id}") |> json_response(200) |> Map.get("data")
      assert data["id"] == user.id
      refute Map.has_key?(data, "email")
    end

    test "404s for unknown or malformed ids", %{conn: conn} do
      assert json_response(get(conn, ~p"/api/users/#{Ecto.UUID.generate()}"), 404)
      assert json_response(get(conn, ~p"/api/users/not-a-uuid"), 404)
    end
  end

  describe "GET /api/users/:id/chatrooms" do
    test "hides private rooms from others but shows them to the owner", %{conn: conn} do
      owner = user_fixture()
      chatroom_fixture(owner, %{name: "Open"})
      chatroom_fixture(owner, %{name: "Hidden", is_private: true})

      others_view = conn |> get(~p"/api/users/#{owner.id}/chatrooms") |> json_response(200)
      assert Enum.map(others_view["data"], & &1["name"]) == ["Open"]

      own_view =
        conn |> as(owner) |> get(~p"/api/users/#{owner.id}/chatrooms") |> json_response(200)

      assert length(own_view["data"]) == 2
    end
  end

  describe "/api/me" do
    test "requires a user", %{conn: conn} do
      assert json_response(get(conn, ~p"/api/me"), 401)
      assert json_response(conn |> put_req_header("x-user-id", "bogus") |> get(~p"/api/me"), 401)
    end

    test "returns and updates the current user", %{conn: conn} do
      user = user_fixture()

      assert json_response(conn |> as(user) |> get(~p"/api/me"), 200)["data"]["email"] ==
               user.email

      conn = conn |> as(user) |> patch(~p"/api/me", %{display_name: "Shamu", username: "hijack"})
      data = json_response(conn, 200)["data"]
      assert data["display_name"] == "Shamu"
      # username is not editable via this endpoint
      assert data["username"] == user.username
    end
  end
end
