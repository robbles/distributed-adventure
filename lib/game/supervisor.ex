defmodule Game.Supervisor do
  use Supervisor.Behaviour

  def start_link(config_file) do
    :supervisor.start_link(__MODULE__, [config_file])
  end

  def init(config_file) do
    children = [
      # Define workers and child supervisors to be supervised
      worker(Game.RoomServer, config_file),
      worker(Game.Server, ["Rob"])
    ]

    # See http://elixir-lang.org/docs/stable/Supervisor.Behaviour.html
    # for other strategies and supported options
    supervise children, strategy: :one_for_one
  end
end
