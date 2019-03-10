defmodule Scnle.State do
  @moduledoc """
  Behaviour for modules that care about leader functions
  Not used for now but will be used for master-slaves pattern later
  """

  @type node_status() ::
          :idle
          | :waiting_receive_pong
          | :waiting_receive_alive
          | :waiting_receive_finethanks
          | :waiting_iamking

  @enforce_keys [:wait_until_start_election, :status, :leader, :last_ping_at]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          wait_until_start_election: DateTime.t() | nil,
          last_ping_at: DateTime.t() | nil,
          status: node_status,
          leader: node | nil
        }

  @spec new() :: t()
  def new() do
    %__MODULE__{
      status: :idle,
      wait_until_start_election: nil,
      leader: nil,
      last_ping_at: nil
    }
  end
end
