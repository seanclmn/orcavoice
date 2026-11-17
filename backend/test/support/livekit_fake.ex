defmodule Orcavoice.LiveKitFake do
  @moduledoc """
  In-memory stand-in for the LiveKit server API used by `Chat.Speakers`.
  State is keyed by room name, so async tests using unique rooms don't collide.
  """

  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  @doc "Adds a participant who joined at `joined_at` as a listener."
  def join(room, identity, joined_at, opts \\ []) do
    p = %{
      identity: identity,
      joined_at: joined_at,
      can_publish: Keyword.get(opts, :can_publish, false),
      kind: Keyword.get(opts, :kind, "STANDARD")
    }

    Agent.update(__MODULE__, &Map.update(&1, room, [p], fn ps -> ps ++ [p] end))
  end

  def leave(room, identity) do
    Agent.update(
      __MODULE__,
      fn state ->
        Map.update(state, room, [], fn ps -> Enum.reject(ps, &(&1.identity == identity)) end)
      end
    )
  end

  @doc "Identities currently allowed to speak, in join order."
  def speakers(room) do
    {:ok, ps} = list_participants(room)
    ps |> Enum.filter(& &1.can_publish) |> Enum.sort_by(& &1.joined_at) |> Enum.map(& &1.identity)
  end

  def list_participants(room), do: {:ok, Agent.get(__MODULE__, &Map.get(&1, room, []))}

  def set_can_publish(room, identity, can_publish?) do
    Agent.update(__MODULE__, fn state ->
      Map.update(state, room, [], fn ps ->
        Enum.map(ps, fn
          %{identity: ^identity} = p -> %{p | can_publish: can_publish?}
          p -> p
        end)
      end)
    end)
  end
end
