defrecord ConnectionState, socket: nil, name: "PLAYER"

defmodule Game.SocketProtocol do
  @behaviour :ranch_protocol
  use GenFSM.Behaviour

  @listener :game_tcp_listener
  @transport :ranch_tcp

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
    IO.puts "SocketProtocol: init/4 called"

    # Initialize gen_fsm process and ranch protocol
    :ok = :proc_lib.init_ack({:ok, self})
    :ok = :ranch.accept_ack(ref)

    # Allow receiving socket data through handle_info
    :ok = @transport.setopts(socket, [active: :once])
    
    # Start gen_fsm loop
    state = ConnectionState.new socket: socket
    :gen_fsm.enter_loop(__MODULE__, [], :connected, state)
  end

  # gen_fsm init/1
  def init(_), do: {:stop, :not_implemented}

  # Async message handling
  def handle_info({:tcp, socket, bin}, state, context = ConnectionState[]) do
    IO.puts "SocketProtocol: data received from socket"

    # Flow control: enable forwarding of next TCP message
    :ok = @transport.setopts(socket, [active: :once])
    
    # Use FSM functions to decide next state
    apply(__MODULE__, state, [bin, context])
  end

  def handle_info({:tcp_closed, socket}, _state, context = ConnectionState[]) do
    IO.puts "SocketProtocol: socket closed"
    {:stop, "client disconnected", context}
  end

  # Event handlers
  def connected(<< "name ", arg :: binary >>, context = ConnectionState[socket: socket]) do
    name = String.rstrip arg

    @transport.send socket, "Your name is now \"#{name}\"!\n"

    # TODO: add name to state
    { :next_state, :connected, context }
  end

  def connected(data, context = ConnectionState[socket: socket]) do
    IO.puts "SocketProtocol: handling data in :connected state"
    IO.puts inspect data

    # Echo back data
    @transport.send(socket, String.rstrip(data) <> "!\n")

    { :next_state, :connected, context }
  end

end
