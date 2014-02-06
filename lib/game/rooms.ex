defmodule Game.Rooms do

defrecord Room, label: "", desc: "", exits: []

alias HTTPotion.Response
alias HTTPotion.HTTPError
alias Game.Rooms.Fetcher
alias Game.Rooms.Parser

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

  def delayed() do
    :gen_server.call(@name, :delayed)
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

  def handle_call(:delayed, sender, state) do
    spawn(fn ->
      :timer.sleep 4000
      :gen_server.reply sender, {:response, "hello world!"}
    end)

    {:noreply, state}
  end

  def handle_call([get: room_name], _sender, state = RoomServer[rooms: rooms]) do
    reply = case get_room_by_name(rooms, room_name) do
      :undefined -> {:error, "Room not found"}
      {:error, "The door won't budge. Maybe it's locked?"}
      room -> {:ok, room}
    end

    {:reply, reply, state}
  end

  # Fetching rooms

  # TODO: try cache first, then HTTP on missing key

  def get_room_by_name(rooms, << "http://"::binary, url::binary >>) do
    case Fetcher.fetch_room_http("http://" <> url) do
      {:ok, room_json} ->
        Parser.parse_room_json room_json

      other -> other
    end
  end

  def get_room_by_name(rooms, room_name) do
    room_name = convert_room_name room_name
    :proplists.get_value room_name, rooms
  end

  defp convert_room_name(:start), do: "start"
  defp convert_room_name(room_name), do: room_name

end

defmodule Fetcher do

  def fetch_room_http(url) do
    try do
      case HTTPotion.get url do

        Response[body: body, status_code: status] when status in 200..299 ->
          {:ok, body}

        Response[body: body, status_code: status] ->
          {:error, status}
      end
    rescue
      HTTPError -> {:error, "connection error"}
    end
  end

end

defmodule Parser do

  # Utility functions
  def read_rooms_file(path) do
    IO.puts "reading rooms from #{path}"
    File.read(path) |> parse_rooms_file
  end

  defp parse_rooms_file({:ok, room_json}) do
    try do
      Jsonex.decode(room_json) |> parse_room_list
    rescue
      ArgumentError -> {:error, "Bad JSON"}
    end
  end

  defp parse_rooms_file({:error, reason}) do
    {:error, reason}
  end

  defp parse_room_list(room_list) do
    rooms = Enum.map room_list, fn {key, element} ->
      {key, proplist_to_room(element)}
    end

    {:ok, rooms}
  end

  def parse_room_json(room_json) do
    try do
      Jsonex.decode(room_json) |> proplist_to_room
    rescue
      ArgumentError -> {:error, "Bad JSON"}
    end
  end

  def proplist_to_room(data) do
    label = :proplists.get_value("label", data)
    desc = :proplists.get_value("description", data)
    exits = :proplists.get_value("exits", data)
    Room.new label: label, desc: desc, exits: exits
  end

end

end
