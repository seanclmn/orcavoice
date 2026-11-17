defmodule Orcavoice.Chat.Occupancy do
  @moduledoc """
  Live participant counts per chatroom, read from LiveKit.

  One process per app node polls LiveKit every few seconds and writes the
  counts into an ETS table. API requests read ETS only, so LiveKit sees
  one request per node per interval no matter how many clients are asking.

  Next step at larger scale: replace polling with LiveKit webhooks
  (participant_joined/left) fanned out over Phoenix.PubSub.
  """

  use GenServer
  require Logger

  @table __MODULE__
  @default_interval_ms 3_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Participant counts for the given chatroom ids. Unknown/empty rooms are 0."
  def counts(room_ids) when is_list(room_ids) do
    Map.new(room_ids, fn id ->
      case :ets.lookup(@table, id) do
        [{^id, count}] -> {id, count}
        [] -> {id, 0}
      end
    end)
  end

  @doc "Replaces all stored counts. Used by the poller, and by tests."
  def put_counts(counts) when is_map(counts) do
    stale = :ets.select(@table, [{{:"$1", :_}, [], [:"$1"]}]) -- Map.keys(counts)
    :ets.insert(@table, Map.to_list(counts))
    Enum.each(stale, &:ets.delete(@table, &1))
    :ok
  end

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    state = %{
      interval: Keyword.get(opts, :interval_ms, @default_interval_ms),
      poll?: Keyword.get(opts, :poll, true)
    }

    if state.poll?, do: send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    case Orcavoice.LiveKit.list_room_counts() do
      {:ok, counts} ->
        put_counts(counts)

      {:error, reason} ->
        # Keep the last known counts rather than flashing everything to 0.
        Logger.warning("Occupancy poll failed: #{inspect(reason)}")
    end

    Process.send_after(self(), :poll, state.interval)
    {:noreply, state}
  end
end
