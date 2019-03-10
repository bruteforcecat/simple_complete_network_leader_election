defmodule ScnleTest do
  use ExUnit.Case
  doctest Scnle

  setup_all do
    nodes = ScnleTest.Cluster.start_nodes(1)

    on_exit(fn ->
      ScnleTest.Cluster.stop()
    end)

    {:ok, nodes: nodes}
  end

  test "the first node will be leader", %{nodes: nodes} do
    num_process = Process.list() |> Enum.count()

    [node1] = nodes

    get_node_list = fn -> nodes end
    get_self_node = fn -> node1 end

    Node.spawn_link(node1, Scnle.Node, :start_link, [])

    :timer.sleep(3000)
    result = :rpc.block_call(node1, Scnle.Node, :get_leader, [])
    assert result === node1
  end

  test "join an existing cluster will cause election", %{nodes: nodes} do
    new_node = ScnleTest.Cluster.spawn_new_node()
    assert true
  end
end
