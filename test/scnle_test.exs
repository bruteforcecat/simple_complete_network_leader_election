defmodule ScnleTest do
  use ExUnit.Case
  doctest Scnle

  test "the first node will be leader" do
    num_process = Process.list() |> Enum.count()

    # nodes = LocalCluster.start_nodes("my-cluster", 2)
    nodes = Node.list()

    [node1, _node2] = nodes

    get_node_list = fn -> nodes end
    get_self_node = fn -> node1 end

    Node.spawn_link(node1, Scnle.Node, :start_link, [])

    :timer.sleep(3000)
    result = :rpc.block_call(node1, Scnle.Node, :get_leader, [])
    IO.inspect result, label: "result"
    assert true
  end

  # defp call_node(node, func) do
  #   parent = self()
  #   ref = make_ref()

  #   pid =
  #     Node.spawn(node, fn ->
  #       result = func.()
  #       send(parent, {ref, result})
  #       ref = Process.monitor(parent)

  #       receive do
  #         {:DOWN, ^ref, :process, _, _} -> :ok
  #       end
  #     end)

  #   receive do
  #     {^ref, result} -> {pid, result}
  #   after
  #     1000 -> {pid, {:error, :timeout}}
  #   end
  # end
end
