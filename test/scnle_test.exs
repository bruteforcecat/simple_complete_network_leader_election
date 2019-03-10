defmodule ScnleTest do
  use ExUnit.Case
  doctest Scnle

  test "the first node will be leader" do
    num_process = Process.list() |> Enum.count()

    nodes = Node.list()

    [node1] = nodes

    get_node_list = fn -> nodes end
    get_self_node = fn -> node1 end

    Node.spawn_link(node1, Scnle.Node, :start_link, [])

    :timer.sleep(3000)
    result = :rpc.block_call(node1, Scnle.Node, :get_leader, [])
    IO.inspect result, label: "result"
    assert result === node1
  end

end
