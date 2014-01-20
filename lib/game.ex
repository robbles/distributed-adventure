defmodule Game do
  use Application.Behaviour

  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  def start(_type, _args) do

    # Start supervisor for game and room servers
    Game.Supervisor.start_link "rooms.json"

    # Start socket pool
    Game.SocketProtocol.listen 5555

  end
end
