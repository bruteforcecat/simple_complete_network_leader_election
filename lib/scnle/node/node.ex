defmodule Scnle.Node do
  @moduledoc """
  The Node module handling leader election
  """

  use GenServer
  require Logger

  alias Scnle.{State, RPC, Network}

  @ping_interval 1000
  @pong_receive_threshold @ping_interval * 4
  @alive_receive_threshold @ping_interval
  @tick_interval 100
  @type node_role() :: :leader | :follower

  # client

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

  # server
  def init(_opts) do
    schedule_next_tick()

    state = start_election(State.new())

    {:ok, state}
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
    RPC.send_message(sender, :PONG)

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
    RPC.send_message(sender, :FINETHANKS)

    case get_nodes_with_greater_id(Network.get_self_node()) do
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
         wait_until_start_election: add_milli(DateTime.utc_now(), @ping_interval)
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
          wait_until_start_election: wait_until_start_election
        } = state
      )
      when not is_nil(wait_until_start_election) do
    state =
      if is_after_now?(wait_until_start_election) do
        start_election(state)
      else
        state
      end

    schedule_next_tick()

    {:noreply, state}
  end

  def handle_info(
        :tick,
        %State{
          status: status,
          leader: leader
        } = state
      )
      when status in [:idle, :waiting_receive_pong] do
    new_state =
      case Node.self() do
        ^leader ->
          state

        _ ->
          if state.last_ping_at == nil or
               is_after_now?(add_milli(state.last_ping_at, @ping_interval)) do
            RPC.send_message(state.leader, :PING)
            now = DateTime.utc_now()

            %{
              state
              | status: :waiting_receive_pong,
                last_ping_at: now
            }
            |> case do
              %State{wait_until_start_election: nil} = state ->
                %State{state | wait_until_start_election: add_milli(now, @pong_receive_threshold)}
            end
          else
            state
          end
      end

    schedule_next_tick()

    {:noreply, new_state}
  end

  defp start_election(state) do
    nodes = get_nodes_with_greater_id(get_all_peers())

    Logger.info("Node #{Node.self()} starting election")

    if nodes == [] do
      claim_king(state)
    else
      Enum.each(nodes, &RPC.send_message(&1, :ALIVE?))

      %{
        state
        | leader: nil,
          status: :waiting_receive_alive,
          wait_until_start_election: add_milli(DateTime.utc_now(), @alive_receive_threshold)
      }
    end
  end

  defp claim_king(%State{} = state) do
    Logger.info("Node #{Node.self()} claim king")
    nodes = get_all_peers()
    RPC.send_message(nodes, :IAMTHEKING)

    %State{
      state
      | leader: Network.get_self_node(),
        status: :idle,
        wait_until_start_election: nil
    }
  end

  defp get_all_peers() do
    nodes = Network.get_node_list()

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

  defp schedule_next_tick() do
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp get_nodes_with_greater_id(node_id) do
    Network.get_node_list()
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

  defp is_after_now?(dt) do
    DateTime.compare(DateTime.utc_now(), dt) == :gt
  end
end
