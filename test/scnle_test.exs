defmodule ScnleTest do
  use ExUnit.Case
  doctest Scnle


  test "the first node will be leader" do
    num_process = Process.list |> Enum.count
    nodes = LocalCluster.start_nodes("my-cluster", 1)

    [node1] = nodes

    get_node_list = fn -> nodes end
    get_self_node = fn -> node1 end
    {:ok, node_pid} =
      Scnle.Node.start_link(get_self_node: get_self_node, get_node_list: get_node_list)

    num_process = Process.list |> Enum.count
    nodde1 = Scnle.Node.get_leader(node1)
  end
end
