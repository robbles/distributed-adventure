defrecord ConnectionContext, socket: nil, name: nil

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
    :gen_fsm.enter_loop(__MODULE__, [debug: [:trace]], :connected, context)
  end

  # gen_fsm init/1
  def init(_), do: {:stop, :not_implemented}


  ##### Async message handling #####
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

  defp set_name(name, context = ConnectionContext[socket: socket]) do
    @transport.send socket, "Your name is now \"#{name}\"!\n"
    context.name(name)
  end

  def chat(parts, context = ConnectionContext[socket: socket, name: name]) do
    # Echo back data
    @transport.send(socket, [name, ": ", Enum.join(parts, " "), "\n"])
    context
  end

  ##### Event Handlers #####
  def connected(["/name", name], context), do: {:next_state, :ready, set_name(name, context)}
  def connected(["/quit"], context), do: quit(context)
  def connected(["/help"], context), do: help(:connected, context)

  def ready(["/quit"], context), do: quit(context)
  def ready(["/help"], context), do: help(:ready, context)
  def ready(parts, context), do: {:next_state, :ready, chat(parts, context)}

end
