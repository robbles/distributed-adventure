defrecord Room, label: "", desc: "", exits: []
defrecord RoomServer, path: nil, rooms: []

defmodule Game.Rooms do
  use GenServer.Behaviour

  def get_test_rooms() do
    [
      start: Room.new(label: "Entrance", desc: "The first room. The second room is to the north.", exits: [n: :second]),
      second: Room.new(label: "Second Room", desc: "This is the second room. The first room is to the south. The third room is to the west. The fourth room is to the north.", exits: [s: :start, w: :third, n: :fourth]),
      third: Room.new(label: "Third Room", desc: "This is the third room. The second room is to the east.", exits: [e: :second]),
      fourth: Room.new(label: "Fourth Room", desc: "This is the fourth room. The second room is to the south.", exits: [s: :second])
    ]
  end

  def get_room_by_name(rooms, room_name) do
    Keyword.get rooms, room_name
  end

  # Client functions
  def start(path) do
    {:ok, pid} = :gen_server.start_link(__MODULE__, path, [])               
    pid
  end

  def room(server, room_name) do
    :gen_server.call(server, [get: room_name])
  end

  def valid_move?(direction, Room[label: label, exits: exits]) do
    case Keyword.get exits, direction do
      nil -> {false, "no exit in that direction"}
      room_name -> {true, room_name}
    end
  end

  def quit(server) do
    :gen_server.call(server, :quit)
  end

  # GenServer callbacks
  def init(path) do
    # TODO: read terms from file with :file.consult or JSON
    rooms = get_test_rooms()
    state = RoomServer.new path: path, rooms: rooms

    {:ok, state}
  end

  def handle_call(:quit, _sender, state) do
    {:stop, "Client quit", state}
  end

  def handle_call([get: room_name], _sender, state = RoomServer[rooms: rooms]) do
    reply = case get_room_by_name(rooms, room_name) do
      nil -> {:error, "Room not found"}
      room -> {:ok, room}
    end

    {:reply, reply, state}
  end

end


