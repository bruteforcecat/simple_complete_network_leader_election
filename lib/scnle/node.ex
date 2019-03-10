defmodule Scnle.Node do
  @moduledoc """
  """

  use GenServer

  @waiting_time_in_milli 2000
  @type node_role() :: :leader | :follower

  defmodule State do
    # TODO better naming
    @type node_status() ::
            :idle | :waiting_receive_alive | :waiting_receive_finethanks | :waiting_iamking

    @enforce_keys [:wait_until_start_election, :status, :leader]
    defstruct [:wait_until_start_election, :status, :leader, peers: []]

    @type t :: %__MODULE__{
            wait_until_start_election: DateTime.t() | nil,
            status: node_status,
            leader: node | nil,
            peers: list(node())
          }
  end

  @spec get_status(pid()) :: State.node_status()
  def get_status(_node) do
    :follower
  end

  @spec get_leader() :: node() | nil
  def get_leader() do
    GenServer.call(__MODULE__, :get_leader)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @default_init_args %{
    get_self_node: &Node.self/0,
    get_node_list: &Node.list/0
  }

  @spec init(
          get_self_node: (() -> node()),
          get_node_list: (() -> list(node()))
        ) :: {:ok, State.t()}
  def init(opts \\ []) do
    %{get_self_node: get_self_node, get_node_list: get_node_list} =
      Enum.into(opts, @default_init_args)

    # It's bad practice to use Process Dictionary in general
    # But this time I dun want to sacrifice the clarity of the state of GenServer for easier
    # dependencies injection for testing
    Process.put(:get_self_node, get_self_node)
    Process.put(:get_node_list, get_node_list)

    peers = get_all_peers()
    # notify_peers_join(peers)
    IO.inspect(peers, label: "peers")

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

    Enum.zip(nodes, nodes_result)
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
    Process.get(:get_self_node).()
  end

  defp get_node_list() do
    Process.get(:get_node_list).()
  end

  # assume all communication is async
  defp send_message(nodes, message) when is_list(nodes) do
    Enum.each(nodes, &send_message(&1, message))
  end

  defp send_message(node, message) when is_atom(node) do
    GenServer.cast({__MODULE__, node}, {message, get_self_node()})
  end

  defp start_election(state) do
    nodes = get_nodes_with_greater_id(state.peers)
    IO.puts("starting election")

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
    send_message(state.peers, :IAMTHEKING)

    %State{
      state
      | leader: get_self_node()
    }
  end

  def handle_call(:get_leader, _from, %State{} = state) do
    IO.inspect(state.leader, label: "state.leader")
    {:reply, state.leader, state}
  end

  def handle_call(:is_scnle_node?, _from, %State{} = state) do
    {:reply, true, state}
  end

  def handle_cast({:PING, sender}, %State{} = state) do
    send_message(sender, :PONG)

    {:noreply, state}
  end

  def handle_cast({:PONG, sender}, %State{status: :idle, leader: sender} = state) do
    schedule_ping_leader()

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

  defp schedule_ping_leader() do
    Process.send_after(
      self(),
      :pind_leader,
      @waiting_time_in_milli
    )
  end

  def handle_info(:ping_leader, state) do
    send_message(state.leader, :PING)

    {:noreply,
     %{
       state
       | wait_until_start_election: add_milli(DateTime.utc_now(), @waiting_time_in_milli * 4)
     }}
  end

  defp get_nodes_with_greater_id(node_id) do
    get_node_list()
    |> Enum.filter(&(&1 > node_id))
  end

  # utilts
  def add_milli(%DateTime{} = dt, ms) do
    dt
    |> DateTime.to_unix(:milliseconds)
    |> (&(&1 + ms)).()
    |> DateTime.from_unix()
  end
end
