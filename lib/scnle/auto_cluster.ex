defmodule Scnle.AutoCluster do
  @moduledoc """
  Using simple Epmd for auto clustering
  """
  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # Server code
  def init(_opts) do
    :net_adm.world()
    :net_kernel.monitor_nodes(true)

    {:ok, []}
  end

  def handle_info({:nodeup, node}, state) do
    Logger.info("Node(#{node}) up")
    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("Node(#{node}) down")
    {:noreply, state}
  end
end
