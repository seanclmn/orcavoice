defmodule OrcavoiceWeb.OccupancyTest do
  # Occupancy is a single shared ETS table, so don't run concurrently.
  use OrcavoiceWeb.ConnCase, async: false

  alias Orcavoice.Chat.Occupancy

  setup do
    on_exit(fn -> Occupancy.put_counts(%{}) end)
  end

  test "returns counts for requested rooms, 0 for empty ones", %{conn: conn} do
    [a, b, c] = for _ <- 1..3, do: Ecto.UUID.generate()
    Occupancy.put_counts(%{a => 3, b => 1})

    data = conn |> get(~p"/api/chatrooms/occupancy?#{[ids: "#{a},#{c}"]}") |> json_response(200)
    assert data["data"] == %{a => 3, c => 0}
  end

  test "rooms that disappear from LiveKit drop back to 0", %{conn: conn} do
    a = Ecto.UUID.generate()
    Occupancy.put_counts(%{a => 5})
    Occupancy.put_counts(%{})

    assert json_response(get(conn, ~p"/api/chatrooms/occupancy?#{[ids: a]}"), 200)["data"] == %{
             a => 0
           }
  end

  test "empty ids returns an empty map", %{conn: conn} do
    assert json_response(get(conn, ~p"/api/chatrooms/occupancy"), 200)["data"] == %{}
  end

  test "rejects too many ids", %{conn: conn} do
    ids = Enum.map_join(1..101, ",", fn _ -> Ecto.UUID.generate() end)
    assert json_response(get(conn, ~p"/api/chatrooms/occupancy?#{[ids: ids]}"), 400)
  end
end
