defmodule OrcavoiceWeb.VoiceTest do
  use OrcavoiceWeb.ConnCase, async: true

  import Orcavoice.AccountsFixtures
  import Orcavoice.ChatFixtures

  alias Orcavoice.LiveKit
  alias Orcavoice.LiveKitFake

  defp decode_claims(jwt) do
    [_, payload, _] = String.split(jwt, ".")
    payload |> Base.url_decode64!(padding: false) |> Jason.decode!()
  end

  describe "POST /api/chatrooms/:id/token" do
    test "issues a listen-only join token for the current user", %{conn: conn} do
      user = user_fixture(display_name: "Shamu")
      room = chatroom_fixture()

      data =
        conn
        |> put_req_header("x-user-id", user.id)
        |> post(~p"/api/chatrooms/#{room.id}/token")
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["url"] == "ws://livekit.test"
      assert data["room_name"] == room.id
      assert data["speaker_limit"] == 10

      claims = decode_claims(data["token"])
      assert claims["sub"] == user.id
      assert claims["name"] == "Shamu"
      assert claims["video"]["room"] == room.id
      assert claims["video"]["roomJoin"] == true
      assert claims["video"]["canPublish"] == false
    end

    test "requires a user", %{conn: conn} do
      room = chatroom_fixture()
      assert json_response(post(conn, ~p"/api/chatrooms/#{room.id}/token"), 401)
    end

    test "404s for unknown rooms", %{conn: conn} do
      conn = put_req_header(conn, "x-user-id", user_fixture().id)
      assert json_response(post(conn, ~p"/api/chatrooms/#{Ecto.UUID.generate()}/token"), 404)
    end
  end

  describe "POST /api/livekit/webhook" do
    defp signed_webhook(conn, event, secret \\ "test") do
      body = Jason.encode!(event)

      auth =
        LiveKit.sign_jwt(
          %{
            iss: "test",
            exp: System.system_time(:second) + 60,
            sha256: Base.encode64(:crypto.hash(:sha256, body))
          },
          secret
        )

      conn
      |> put_req_header("content-type", "application/webhook+json")
      |> put_req_header("authorization", auth)
      |> post(~p"/api/livekit/webhook", body)
    end

    test "participant_joined triggers speaker reconciliation", %{conn: conn} do
      room = "room-#{System.unique_integer([:positive])}"
      LiveKitFake.join(room, "alice", 1)

      conn = signed_webhook(conn, %{event: "participant_joined", room: %{name: room}})

      assert response(conn, 200)
      assert LiveKitFake.speakers(room) == ["alice"]
    end

    test "rejects a bad signature", %{conn: conn} do
      room = "room-#{System.unique_integer([:positive])}"
      LiveKitFake.join(room, "alice", 1)

      conn = signed_webhook(conn, %{event: "participant_joined", room: %{name: room}}, "wrong")

      assert response(conn, 401)
      assert LiveKitFake.speakers(room) == []
    end

    test "rejects a tampered body", %{conn: conn} do
      auth =
        LiveKit.sign_jwt(
          %{iss: "test", sha256: Base.encode64(:crypto.hash(:sha256, "original"))},
          "test"
        )

      conn =
        conn
        |> put_req_header("content-type", "application/webhook+json")
        |> put_req_header("authorization", auth)
        |> post(~p"/api/livekit/webhook", ~s({"event":"participant_joined"}))

      assert response(conn, 401)
    end
  end
end
