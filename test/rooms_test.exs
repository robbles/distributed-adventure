defmodule RoomParserTest do
  use ExUnit.Case

  import Game.RoomParser

  @room_data [
    {"label", "Entrance"},
    {"description", "The first room. The second room is to the north."},
    {"exits", [
        {"north", "second"},
        {"west", "third"}
    ]}
  ]

  test "parse_room returns a Room record" do
  assert parse_room(@room_data) == Room[label: "Entrance", desc: "The first room. The second room is to the north.", exits: [
    {"north", "second"},
    {"west", "third"}
  ]]
  end

  test "parse_room_list returns a property list of Rooms" do
    list_data = [
      {"start", @room_data},
      {"other", @room_data}
    ]
    room = parse_room(@room_data)
    assert parse_room_list(list_data) == [
      {"start", room},
      {"other", room}
    ]
  end

end
