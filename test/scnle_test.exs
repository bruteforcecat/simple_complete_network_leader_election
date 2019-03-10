defmodule ScnleTest do
  use ExUnit.Case
  doctest Scnle

  setup do
    nodes = ScnleTest.Cluster.spawn("my-cluster", 1)
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
end
