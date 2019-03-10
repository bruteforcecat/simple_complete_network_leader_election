defmodule ScnleTest do
  use ExUnit.Case
  doctest Scnle

  setup do
    nodes = ScnleTest.Cluster.start_nodes(1)

    on_exit(fn ->
      ScnleTest.Cluster.stop()
    end)

    {:ok, nodes: nodes}
  end

  test "the first node will be leader", %{nodes: nodes} do
    [node1] = nodes

    Node.spawn_link(node1, Scnle.Node, :start_link, [])
    :timer.sleep(100)

    wait_until_leader_elected([node1])
    result = call_node(node1, Scnle.Node, :get_leader, [])
    assert result == node1
  end

  test "join an existing cluster with leader will cause election", %{nodes: [node1]} do
    {:ok, node2} = ScnleTest.Cluster.spawn_new_node()

    Node.spawn_link(node1, Scnle.Node, :start_link, [])
    :timer.sleep(100)
    wait_until_leader_elected([node1])
    # Node.spawn_link(node2, Scnle.Node, :start_link, [])
    call_node(node2, Scnle.Node, :start_link, [])
    # :timer.sleep(100)
    wait_until_leader_elected([node1, node2])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node2
    assert call_node(node2, Scnle.Node, :get_leader, []) == node2
  end

  test "join an existing cluster without leader will cause election", %{nodes: [node1]} do
    {:ok, node2} = ScnleTest.Cluster.spawn_new_node()

    call_node(node1, Scnle.Node, :start_link, [])
    call_node(node2, Scnle.Node, :start_link, [])
    wait_until_leader_elected([node1, node2])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node2
    assert call_node(node2, Scnle.Node, :get_leader, []) == node2
  end

  test "leader leave will cause election", %{nodes: [node1]} do
    {:ok, node2} = ScnleTest.Cluster.spawn_new_node()
    call_node(node1, Scnle.Node, :start_link, [])
    call_node(node2, Scnle.Node, :start_link, [])
    wait_until_leader_elected([node1, node2])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node2
    assert call_node(node2, Scnle.Node, :get_leader, []) == node2

    stop_node(node2)
    wait_until_leader_elected([node1])
    assert call_node(node1, Scnle.Node, :get_leader, []) == node1
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
end
