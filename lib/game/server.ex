defrecord Player, name: ""
defrecord GameState, player: nil, location: nil
defrecord Room, label: "", desc: "", exits: []

alias Game.RoomServer

defmodule Game.Server do
  use GenServer.Behaviour

  # Client functions
  def start_link(player_name) do
    :gen_server.start_link({:local, :games}, __MODULE__, player_name, [])
  end

  def go(direction) do
    :gen_server.call(:games, {:go, direction})
  end

  def quit() do
    :gen_server.call(:games, :quit)
  end

  # GenServer callbacks
  def init(player_name) do
    # TODO: Allow player to change their name later somehow
    player = Player.new name: player_name

    # Assume that room named :start exists
    {:ok, location} = RoomServer.room(:start)

    game = GameState.new player: player, location: location

    {:ok, game}
  end

  def handle_call(:quit, _sender, state) do
    {:stop, "Client quit", state}
  end

  def handle_call({:go, direction}, _sender, game = GameState[location: location]) do

    # Move to new room if possible, return new state
    case RoomServer.valid_move?(direction, location) do

      {true, room_name} ->

        # Fetch new room info and move there
        RoomServer.room(room_name) |> move_to_room(game)

      {false, reason} ->

        # Can't go that way, return error and don't update
        {:reply, {:nope, "Can't go that way: #{reason}"}, game}

    end
  end

  def move_to_room({:ok, room}, game) do
    # Update room and return response
    updated = game.location room
    {:reply, {:yep, room}, updated}
  end

  def move_to_room({:error, reason}, game) do
    # Room is missing, return error and don't update
    {:reply, {:nope, "Can't go that way: #{reason}"}, game}
  end

end
