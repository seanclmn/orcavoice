defmodule Orcavoice.Chat.Speakers do
  @moduledoc """
  Enforces the per-room speaker limit.

  The rule: the `limit` participants who joined a room earliest (and are
  still in it) may speak; everyone else is a listener. When a speaker leaves,
  the longest-waiting listener is promoted.

  Enforcement happens in LiveKit via participant permissions, so a client
  can't bypass it. Everyone joins as a listener (see `LiveKit.join_token/3`)
  and `reconcile/1` runs whenever someone joins or leaves.

  `reconcile/1` is idempotent: it reads the room's actual state from LiveKit
  and corrects it, so duplicated, reordered or missed events heal on the next
  call. Calls for the same room are serialized cluster-wide with a :global
  lock so two concurrent joins can't both take the last slot.
  """

  require Logger

  @default_limit 10

  def limit, do: Application.get_env(:orcavoice, __MODULE__, [])[:limit] || @default_limit

  @doc "Brings `room`'s speaker permissions in line with the speaker rule."
  def reconcile(room) when is_binary(room) do
    :global.trans({{__MODULE__, room}, self()}, fn -> do_reconcile(room) end)
  end

  defp do_reconcile(room) do
    with {:ok, participants} <- api().list_participants(room) do
      speakers =
        participants
        # Only real users count; skip recorders/agents/ingress.
        |> Enum.filter(&(&1.kind == "STANDARD"))
        |> Enum.sort_by(&{&1.joined_at, &1.identity})
        |> Enum.take(limit())
        |> MapSet.new(& &1.identity)

      changes =
        participants
        |> Enum.filter(&(&1.kind == "STANDARD"))
        |> Enum.map(&{&1.identity, &1.can_publish, MapSet.member?(speakers, &1.identity)})
        |> Enum.filter(fn {_, can_publish, should_speak} -> can_publish != should_speak end)
        |> Enum.map(fn {identity, _, should_speak} -> {identity, should_speak} end)

      Enum.each(changes, fn {identity, should_speak} ->
        case api().set_can_publish(room, identity, should_speak) do
          :ok ->
            :ok

          # They may have left between listing and updating; next event fixes it.
          {:error, reason} ->
            Logger.warning("Speaker update failed for #{identity} in #{room}: #{inspect(reason)}")
        end
      end)

      {:ok, changes}
    end
  end

  defp api, do: Application.get_env(:orcavoice, :livekit_api, Orcavoice.LiveKit)
end
