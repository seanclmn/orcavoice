defmodule Orcavoice.SpeakersTest do
  use ExUnit.Case, async: true

  alias Orcavoice.Chat.Speakers
  alias Orcavoice.LiveKitFake

  setup do
    %{room: "room-#{System.unique_integer([:positive])}"}
  end

  defp join_many(room, range), do: for(i <- range, do: LiveKitFake.join(room, "u#{i}", i))
  defp ids(range), do: Enum.map(range, &"u#{&1}")

  test "the limit defaults to 10" do
    assert Speakers.limit() == 10
  end

  test "first 10 to join may speak, the rest are listeners", %{room: room} do
    join_many(room, 1..12)
    Speakers.reconcile(room)

    assert LiveKitFake.speakers(room) == ids(1..10)
  end

  test "when a speaker leaves, the longest-waiting listener is promoted", %{room: room} do
    join_many(room, 1..12)
    Speakers.reconcile(room)

    LiveKitFake.leave(room, "u3")
    Speakers.reconcile(room)

    assert LiveKitFake.speakers(room) == ids([1, 2, 4, 5, 6, 7, 8, 9, 10, 11])
  end

  test "excess speakers are demoted, latest joiners first", %{room: room} do
    for i <- 1..11, do: LiveKitFake.join(room, "u#{i}", i, can_publish: true)
    Speakers.reconcile(room)

    assert LiveKitFake.speakers(room) == ids(1..10)
  end

  test "non-user participants (agents, recorders) are ignored", %{room: room} do
    LiveKitFake.join(room, "recorder", 0, kind: "EGRESS")
    join_many(room, 1..10)
    Speakers.reconcile(room)

    assert LiveKitFake.speakers(room) == ids(1..10)
  end

  test "reconcile is idempotent", %{room: room} do
    join_many(room, 1..12)
    assert {:ok, changes} = Speakers.reconcile(room)
    assert length(changes) == 10
    assert {:ok, []} = Speakers.reconcile(room)
  end

  test "concurrent reconciles never exceed the limit", %{room: room} do
    join_many(room, 1..30)

    1..20
    |> Task.async_stream(fn _ -> Speakers.reconcile(room) end, max_concurrency: 20)
    |> Stream.run()

    assert LiveKitFake.speakers(room) == ids(1..10)
  end
end
