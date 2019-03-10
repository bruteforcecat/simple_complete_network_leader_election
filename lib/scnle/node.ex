defmodule Scnle.Node do
  @moduledoc """
  """

  use GenServer
  require Logger

  @waiting_time_in_milli 1000
  @type node_role() :: :leader | :follower

  defmodule State do
    # TODO better naming
    @type node_status() ::
            :idle
            | :waiting_receive_pong
            | :waiting_receive_alive
            | :waiting_receive_finethanks
            | :waiting_iamking

    @enforce_keys [:wait_until_start_election, :status, :leader]
    defstruct [:wait_until_start_election, :status, :leader, peers: []]

    @type t :: %__MODULE__{
            wait_until_start_election: DateTime.t() | nil,
            status: node_status,
            leader: node | nil,
            peers: list(node())
          }
  end

  @spec get_role(node()) :: node_role()
  def get_role(node) do
    if get_leader(node) == node do
      :leader
    else
      :follower
    end
  end

  @spec get_leader(node()) :: node() | nil
  def get_leader(node \\ Node.self()) do
    GenServer.call({__MODULE__, node}, :get_leader)
  end

  @spec get_status(node()) :: node() | nil
  def get_status(node \\ Node.self()) do
    GenServer.call({__MODULE__, node}, :get_status)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    peers = get_all_peers()
    # notify_peers_join(peers)

    schedule_next_tick()

    state =
      start_election(%State{
        peers: peers,
        wait_until_start_election: nil,
        status: :idle,
        leader: nil
      })

    {:ok, state}
  end

  defp get_all_peers() do
    nodes = get_node_list()

    nodes_result =
      nodes
      |> Enum.map(&Task.async(fn -> is_scnle_node?(&1) end))
      |> Enum.map(fn pid ->
        Task.await(pid, 5000)
      end)

    nodes
    |> Enum.zip(nodes_result)
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  defp is_scnle_node?(node) when is_atom(node) do
    try do
      GenServer.call({__MODULE__, node}, :is_scnle_node?)
      # it catch exit caused by sending call to connected non-scnle node
    catch
      :exit, {:noproc, _} ->
        false
    end
  end

  defp get_self_node() do
    Node.self()
  end

  defp get_node_list() do
    Node.list()
  end

  # assume all communication is async
  defp send_message(nodes, message) when is_list(nodes) do
    Enum.each(nodes, &send_message(&1, message))
  end

  defp send_message(node, message) when is_atom(node) do
    Logger.info(
      "Node #{Node.self()} send to Node #{inspect(node)} : send_message #{inspect(message)}"
    )

    GenServer.cast({__MODULE__, node}, {message, get_self_node()})
  end

  defp start_election(state) do
    nodes = get_nodes_with_greater_id(get_all_peers())

    Logger.info("starting election")

    if nodes == [] do
      claim_king(state)
    else
      Enum.each(nodes, &send_message(&1, :ALIVE?))

      %{
        state
        | leader: nil,
          status: :waiting_receive_alive,
          wait_until_start_election: add_milli(DateTime.utc_now(), @waiting_time_in_milli)
      }
    end
  end

  defp claim_king(%State{} = state) do
    nodes = get_all_peers()
    send_message(nodes, :IAMTHEKING)

    %State{
      state
      | leader: get_self_node()
    }
  end

  def handle_call(:get_leader, _from, %State{} = state) do
    {:reply, state.leader, state}
  end

  def handle_call(:get_status, _from, %State{} = state) do
    {:reply, state.status, state}
  end

  def handle_call(:is_scnle_node?, _from, %State{} = state) do
    {:reply, true, state}
  end

  def handle_cast({:PING, sender}, %State{} = state) do
    send_message(sender, :PONG)

    {:noreply, state}
  end

  def handle_cast({:PONG, sender}, %State{status: :waiting_receive_pong, leader: sender} = state) do
    {:noreply, %{state | wait_until_start_election: nil}}
  end

  # This happen when the leader in the current node view change after the previous ping send
  # we will just ignore it
  def handle_cast({:PONG, _sender}, %State{status: _, leader: _leader} = state) do
    {:noreply, state}
  end

  def handle_cast({:ALIVE?, sender}, %State{} = state) do
    send_message(sender, :FINETHANKS)

    case get_nodes_with_greater_id(get_self_node()) do
      [] ->
        {:noreply, claim_king(state)}

      [_ | _] ->
        {:noreply, start_election(state)}
    end
  end

  def handle_cast({:FINETHANKS, _sender}, %{status: :waiting_receive_alive} = state) do
    {:noreply,
     %{
       state
       | status: :waiting_receive_finethanks,
         wait_until_start_election: add_milli(DateTime.utc_now(), @waiting_time_in_milli)
     }}
  end

  def handle_cast({:IAMTHEKING, sender}, %State{} = state) do
    {:noreply,
     %{
       state
       | leader: sender,
         wait_until_start_election: nil
     }}
  end

  def handle_info(
        :tick,
        %State{
          # status: :idle,
          wait_until_start_election: wait_until_start_election
        } = state
      )
      when not is_nil(wait_until_start_election) do
    state =
      case DateTime.compare(DateTime.utc_now(), wait_until_start_election) do
        :gt ->
          start_election(state)

        _ ->
          state
      end

    schedule_next_tick()

    {:noreply, state}
  end

  def handle_info(
        :tick,
        %{
          status: status,
          leader: leader
        } = state
      )
      when status in [:idle, :waiting_receive_pong] do
    new_state =
      if Node.self() == leader do
        state
      else
        send_message(state.leader, :PING)

        %{
          state
          | status: :waiting_receive_pong,
            wait_until_start_election: add_milli(DateTime.utc_now(), @waiting_time_in_milli * 4)
        }
      end

    schedule_next_tick()

    {:noreply, new_state}
  end

  defp schedule_next_tick() do
    Process.send_after(self(), :tick, @waiting_time_in_milli)
  end

  defp get_nodes_with_greater_id(node_id) do
    get_node_list()
    |> Enum.filter(&(&1 > node_id))
  end

  # utilts
  def add_milli(%DateTime{} = dt, ms) do
    {:ok, result} =
      dt
      |> DateTime.to_unix(:milliseconds)
      |> (&(&1 + ms)).()
      |> DateTime.from_unix(:milliseconds)

    result
  end
end
