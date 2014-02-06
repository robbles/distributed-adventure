defmodule Game do
  use Application.Behaviour

  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  def start(_type, _args) do
    public_dir = get_public_dir()
    base_rooms = Path.join public_dir, "base_rooms.json"

    # Start supervisor for game and room servers
    {:ok, supervisor} = Game.Supervisor.start_link base_rooms

    # Start socket pool
    Game.SocketProtocol.listen 5555

    port = 8080

    # host: [{path, handler, opts}...]
    routing = [
      _: [
        {"/[...]", :cowboy_static, {:dir, public_dir}}
      ]
    ]

    dispatch = :cowboy_router.compile(routing)
    {:ok, _} = :cowboy.start_http(:http, 100,
                                  [port: port],
                                  [env: [dispatch: dispatch]])

    IO.puts "HTTP Server listening on #{port}, serving from #{public_dir}"


    {:ok, supervisor}
  end

  def get_public_dir do
    Path.join(__DIR__, "../public/") |> Path.expand
  end
end
