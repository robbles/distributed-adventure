defmodule Game.Rooms do

defrecord Room, label: "", desc: "", exits: []

defmodule Server do
  use GenServer.Behaviour

  defrecord RoomServer, path: nil, rooms: []

  @name :room_server

  # Client functions
  def start_link(path) when is_binary path do
    IO.puts "Rooms: starting link"
    :gen_server.start_link({:local, @name}, __MODULE__, path, [debug: [:trace]])
  end

  def room(room_name) do
    :gen_server.call(@name, [get: room_name])
  end

  def valid_move?(direction, Room[exits: exits]) do
    case :proplists.get_value direction, exits do
      :undefined -> {false, "no exit in that direction"}
      room_name -> {true, room_name}
    end
  end

  def quit() do
    :gen_server.call(@name, :quit)
  end

  # GenServer callbacks
  def init(path) when is_binary path do
    IO.puts "Rooms: started with config path #{path}"

    {:ok, rooms} = Game.Rooms.Parser.read_rooms_file(path)

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

  # Utility functions
  def get_test_rooms() do
    [
      start: Room.new(label: "Entrance", desc: "The first room. The second room is to the north.", exits: [north: :second]),
      second: Room.new(label: "Second Room", desc: "This is the second room. The first room is to the south. The third room is to the west. The fourth room is to the north.", exits: [south: :start, west: :third, north: :fourth]),
      third: Room.new(label: "Third Room", desc: "This is the third room. The second room is to the east.", exits: [east: :second]),
      fourth: Room.new(label: "Fourth Room", desc: "This is the fourth room. The second room is to the south.", exits: [south: :second])
    ]
  end

  defp get_room_by_name(rooms, room_name) do
    room_name = convert_room_name room_name
    :proplists.get_value room_name, rooms
  end

  defp convert_room_name(:start), do: "start"
  defp convert_room_name(room_name), do: room_name

end


defmodule Parser do

  # Utility functions
  def read_rooms_file(path) do
    IO.puts "reading rooms from #{path}"
    File.read(path) |> parse_rooms_file
  end

  defp parse_rooms_file({:ok, room_data}) do
    room_list = Jsonex.decode(room_data)
    parse_room_list(room_list)
  end

  defp parse_rooms_file({:error, reason}) do
    {:error, reason}
  end

  def parse_room_list(room_list) do
    # TODO: add to hash instead of just returning keyword list
    IO.puts "Parsing JSON list of rooms"

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

end
