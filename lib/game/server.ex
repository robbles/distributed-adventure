defrecord Player, pid: nil, name: "", location: nil
defrecord GameState, players: nil

alias Game.Rooms

defmodule Game.Server do
  use GenServer.Behaviour

  @name :game_server

  # Client functions
  def start_link() do
    IO.puts "Game.Server: starting link"
    :gen_server.start_link({:local, @name}, __MODULE__, [], [debug: [:trace]])
  end

  def join(name) do
    :gen_server.call(@name, {:join, name})
  end

  def go(direction) do
    :gen_server.call(@name, {:go, direction})
  end

  def quit() do
    :gen_server.call(@name, :quit)
  end

  # GenServer callbacks
  def init(_) do
    IO.puts "Game.Server: started"
    players = PlayerStore.new

    game = GameState.new(players: players)
    IO.puts inspect game

    IO.puts "Game.Server: ready!"
    {:ok, game}
  end

  def handle_call({:join, name}, {sender, _}, game = GameState[players: players]) do
    # Request special :start room for initial location
    {:ok, location} = Rooms.Server.room(:start)

    player = Player.new pid: sender, name: name, location: location

    players_new = PlayerStore.add(players, sender, player)
    {:reply, {:ok, location}, game.players(players_new)}
  end

  def handle_call(:quit, {sender, _}, game = GameState[players: players]) do
    players_new = PlayerStore.remove(players, sender)
    {:reply, {:ok, :quitting}, game.players(players_new)}
  end

  def handle_call({:go, direction}, {sender, _}, game = GameState[players: players]) do
    PlayerStore.get(players, sender) |> handle_go(direction, game)
  end

  ##### Internal API #####

  def handle_go(player = Player[location: location], direction, game = GameState[players: players]) do
    # Move to new room if possible, return new state
    case Rooms.Server.valid_move?(direction, location) do

      {true, room_name} ->

        # Fetch new room info and move there
        Rooms.Server.room(room_name) |> move_to_room(game, player)

      {false, reason} ->

        # Can't go that way, return error and don't update
        {:reply, {:error, reason}, game}

    end
  end

  def handle_go(_, direction, game) do
    {:reply, {:error, "Player not found"}, game}
  end

  defp move_to_room({:ok, room}, game = GameState[players: players], Player[pid: pid]) do
    # Update room and return response
    players_new = PlayerStore.set_location(players, pid, room)
    {:reply, {:ok, room}, game.players(players_new)}
  end

  defp move_to_room({:error, reason}, game, _) do
    # Room is missing, return error and don't update
    {:reply, {:error, "Can't go that way: #{reason}"}, game}
  end

end

defmodule PlayerStore do
  # Implementation of PlayerStore is just backed by a HashDict for now, but can
  # be turned into a gen_server or external cache later if necessary

  def new() do
    HashDict.new
  end

  def add(ref, id, player) do
    HashDict.put ref, id, player
  end

  def remove(ref, id) do
    HashDict.delete ref, id
  end

  def get(ref, id) do
    HashDict.get ref, id, nil
  end

  def set_location(ref, id, location) do
    player = get(ref, id)
    add(ref, id, player.location(location))
  end
end
