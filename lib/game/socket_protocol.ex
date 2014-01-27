defrecord ConnectionContext, socket: nil, name: nil, location: :no_room

# TODO: add /go command and wire up game server command

# TODO: pretty formatting of room descriptions

defmodule Game.SocketProtocol do
  @behaviour :ranch_protocol
  use GenFSM.Behaviour

  @listener :game_tcp_listener
  @transport :ranch_tcp

  @welcome_message "
Welcome to Distributed Adventure!
Please set your handle with /name <your name>

"

  def listen(port, num_acceptors // 100) do
    IO.puts "SocketProtocol: starting listener on port #{port}"

    {:ok, _ref} = :ranch.start_listener(@listener,
      num_acceptors, @transport, [port: port], __MODULE__, [])
  end

  def start_link(ref, socket, _transport, _opts) do
    IO.puts "SocketProtocol: starting linked process"

    # Use proc_lib to start for compatibility with gen_fsm
    :proc_lib.start_link(__MODULE__, :init, [ref, socket])
  end

  # ranch_protocol init/4
  def init(ref, socket) do
    IO.puts "SocketProtocol: init/2 called"

    # Initialize gen_fsm process and ranch protocol
    :ok = :proc_lib.init_ack({:ok, self})
    :ok = :ranch.accept_ack(ref)

    # Enable receiving socket data through handle_info and line buffering
    :ok = @transport.setopts(socket, [active: :once, packet: :line, recbuf: 1024])
    
    # Setup context and send welcome message
    context = ConnectionContext.new socket: socket
    welcome(context)

    # Become a gen_fsm server
    :gen_fsm.enter_loop(__MODULE__, [debug: [:trace]], :waiting_for_name, context)
  end

  # gen_fsm init/1
  def init(_), do: {:stop, :not_implemented}


  ##### Async message handling #####
  def handle_info({:tcp_closed, _socket}, :ready, context = ConnectionContext[]) do
    IO.puts "SocketProtocol: socket closed"

    # Disconnect from server if client hard disconnects
    Game.Server.quit

    {:stop, "client disconnected", context}
  end

  def handle_info({:tcp_closed, _socket}, _state, context = ConnectionContext[]) do
    IO.puts "SocketProtocol: socket closed"
    {:stop, "client disconnected", context}
  end

  def handle_info({:tcp, socket, bin}, state, context = ConnectionContext[]) do
    # Flow control: enable forwarding of next TCP message
    :ok = @transport.setopts(socket, [active: :once])
    
    handle_line(String.rstrip(bin), state, context)
  end

  defp handle_line(line, state, context = ConnectionContext[socket: socket]) do
    IO.puts "Received: #{inspect line}"

    args = :binary.split(line, " ", [:global])

    # Use FSM functions to decide next state
    # TODO: catch badmatch error and return a generic message instead of dying
    result = try do
      apply(__MODULE__, state, [args, context])
    rescue
      FunctionClauseError -> no_line_match(line, state, context)
    end

    # Make sure prompt is shown for next line
    @transport.send socket, "> "

    # Go to next state
    result
  end


  ##### Common handlers for multiple states #####
  defp welcome(context = ConnectionContext[socket: socket]) do
    @transport.send socket, @welcome_message
    @transport.send socket, "> "
  end

  defp quit(context = ConnectionContext[socket: socket]) do
    @transport.send socket, "bye!\n"
    {:stop, :client_quit, context}
  end

  defp help(state, context = ConnectionContext[socket: socket]) do
    @transport.send socket, "Use '/name <your name>' to set your name\n"
    {:next_state, state, context}
  end

  defp no_line_match(line, state, context = ConnectionContext[socket: socket]) do
    @transport.send socket, "Sorry, I couldn't quite parse that. Try '/help'\n"
    {:next_state, state, context}
  end

  defp register(name, context = ConnectionContext[socket: socket]) do
    @transport.send socket, "Your name is now \"#{name}\"!\n"

    {:ok, room} = Game.Server.join name
    display_room(socket, room)

    {:next_state, :ready, context.name(name).location(room)}
  end

  defp go(direction, context = ConnectionContext[socket: socket]) do
    case Game.Server.go(direction) do
      {:ok, room} ->
        display_room socket, room
        {:next_state, :ready, context.location(room)}

      {:error, reason} ->
        display_error socket, reason
        {:next_state, :ready, context}
    end
  end

  defp display_room(socket, room) do
    exits_desc = :proplists.get_keys(room.exits) |> Enum.join " and "

    @transport.send socket, "You are now at \"#{room.label}\"\n\n#{room.desc}\n\n"
    @transport.send socket, "Exits are to the #{exits_desc}.\n"
  end

  defp display_error(socket, message) do
    @transport.send socket, "NOPE: #{message}\n\n"
  end

  defp chat(parts, context = ConnectionContext[socket: socket, name: name]) do
    # Echo back data
    @transport.send(socket, [name, ": ", Enum.join(parts, " "), "\n"])
    context
  end

  ##### Event Handlers #####
  def waiting_for_name(["/name", name], context), do: register(name, context)
  def waiting_for_name(["/quit"], context), do: quit(context)
  def waiting_for_name(["/help"], context), do: help(:waiting_for_name, context)

  def ready(["/help"], context), do: help(:ready, context)
  def ready(["/go", direction], context), do: go(direction, context)
  def ready(["/quit"], context) do
    Game.Server.quit
    quit(context)
  end

  def ready(parts, context), do: {:next_state, :ready, chat(parts, context)}

end
