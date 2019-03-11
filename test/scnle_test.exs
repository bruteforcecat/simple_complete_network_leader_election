defmodule ScnleTest do
  use ExUnit.Case
  doctest Scnle

  setup do
    ScnleTest.Cluster.start_cluster()
    node1 = start_new_node()

    on_exit(fn ->
      ScnleTest.Cluster.stop()
    end)

    {:ok, node1: node1}
  end

  test "the first node will start with idle state", %{node1: node1} do
    assert Scnle.get_status(node1) == :idle
  end

  test "the first node will be leader eventually", %{node1: node1} do
    wait_until_leader_elected([node1])
    result = call_node(node1, Scnle.Node, :get_leader, [])
    assert Scnle.get_status(node1) == :idle
    assert result == node1
  end

  test "join an existing cluster with leader will cause election", %{node1: node1} do
    wait_until_leader_elected([node1])
    node2 = start_new_node()
    wait_until_leader_elected([node1, node2])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node2
    assert call_node(node2, Scnle.Node, :get_leader, []) == node2
  end

  test "join an existing cluster without leader will cause election", %{node1: node1} do
    node2 = start_new_node()
    wait_until_leader_elected([node1, node2])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node2
    assert call_node(node2, Scnle.Node, :get_leader, []) == node2
  end

  test "leader leave will cause election", %{node1: node1} do
    node2 = start_new_node()
    wait_until_leader_elected([node1, node2])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node2
    assert call_node(node2, Scnle.Node, :get_leader, []) == node2

    stop_node(node2)
    wait_until_leader_elected([node1])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node1
  end

  test "follower leave will not cause a election", %{node1: node1} do
    node2 = start_new_node()
    node3 = start_new_node()
    wait_until_leader_elected([node1, node2, node3])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node3
    assert call_node(node2, Scnle.Node, :get_leader, []) == node3
    assert call_node(node3, Scnle.Node, :get_leader, []) == node3

    stop_node(node2)
    wait_until_leader_elected([node1, node3])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node3
    assert call_node(node3, Scnle.Node, :get_leader, []) == node3
  end

  test "cluster with 20 nodes" do
    ScnleTest.Cluster.stop()
    nodes = ScnleTest.Cluster.start_nodes(20)

    Enum.each(nodes, fn node ->
      call_node(node, Scnle.Node, :start_link, [])
    end)

    node_with_smallest_id = hd(nodes)
    node_with_largest_id = nodes |> Enum.reverse() |> hd()
    wait_until_leader_elected(nodes)
    assert call_node(node_with_smallest_id, Scnle.Node, :get_leader, []) == node_with_largest_id
  end

  defp stop_node(node) do
    ScnleTest.Cluster.stop_node(node)
  end

  defp call_node(node, m, f, a) do
    :rpc.block_call(node, m, f, a)
  end

  defp wait_until_leader_elected(nodes) do
    nodes
    |> Enum.map(&Scnle.get_role/1)
    |> Enum.find(&(&1 == :leader))
    |> case do
      nil ->
        :timer.sleep(100)
        wait_until_leader_elected(nodes)

      leader ->
        leader
    end
  end

  defp start_new_node() do
    {:ok, node} = ScnleTest.Cluster.spawn_new_node()
    call_node(node, Scnle.Node, :start_link, [])
    node
  end
end
