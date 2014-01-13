defrecord Room, label: "", desc: "", exits: []
defrecord RoomServer, path: nil, rooms: []

defmodule Game.RoomServer do
  use GenServer.Behaviour

  defp get_room_by_name(rooms, room_name) do
    room_name = convert_room_name room_name
    :proplists.get_value room_name, rooms
  end

  defp convert_room_name(:start), do: "start"
  defp convert_room_name(room_name), do: room_name

  # Client functions
  def start(path) do
    {:ok, pid} = :gen_server.start_link(__MODULE__, path, [])               
    pid
  end

  def room(server, room_name) do
    :gen_server.call(server, [get: room_name])
  end

  def valid_move?(direction, Room[label: label, exits: exits]) do
    case :proplists.get_value direction, exits do
      :undefined -> {false, "no exit in that direction"}
      room_name -> {true, room_name}
    end
  end

  def quit(server) do
    :gen_server.call(server, :quit)
  end

  # GenServer callbacks
  def init(path) do
    {:ok, rooms} = Game.RoomParser.read_rooms_file(path)

    state = RoomServer.new path: path, rooms: rooms

    {:ok, state}
  end

  def handle_call(:quit, _sender, state) do
    {:stop, "Client quit", state}
  end

  def handle_call([get: room_name], _sender, state = RoomServer[rooms: rooms]) do
    reply = case get_room_by_name(rooms, room_name) do
      :undefined -> {:error, "Room not found"}
      room -> {:ok, room}
    end

    {:reply, reply, state}
  end

  def get_test_rooms() do
    [
      start: Room.new(label: "Entrance", desc: "The first room. The second room is to the north.", exits: [north: :second]),
      second: Room.new(label: "Second Room", desc: "This is the second room. The first room is to the south. The third room is to the west. The fourth room is to the north.", exits: [south: :start, west: :third, north: :fourth]),
      third: Room.new(label: "Third Room", desc: "This is the third room. The second room is to the east.", exits: [east: :second]),
      fourth: Room.new(label: "Fourth Room", desc: "This is the fourth room. The second room is to the south.", exits: [south: :second])
    ]
  end

end


defmodule Game.RoomParser do

  # Utility functions
  def read_rooms_file(path) do
    IO.puts "reading rooms from #{path}"
    File.read(path) |> parse_rooms_file
  end

  defp parse_rooms_file({:ok, room_data}) do
    room_list = Jsonex.decode(room_data)
    Game.RoomParser.parse_room_list(room_list)
  end

  defp parse_rooms_file({:error, reason}) do
    {:error, reason}
  end

  def parse_room_list(room_list) do
    # TODO: add to hash instead of just returning keyword list

    rooms = Enum.map room_list, fn {key, element} ->
      {key, parse_room(element)}
    end

    {:ok, rooms}
  end

  def parse_room(data) do
    label = :proplists.get_value("label", data)
    desc = :proplists.get_value("description", data)
    exits = :proplists.get_value("exits", data)
    Room.new label: label, desc: desc, exits: exits
  end

end
