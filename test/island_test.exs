defmodule IslandTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias IslandsEngine.{Coordinate, Island}

  test "'new' makes an island" do
    c = %Coordinate{row: 5, col: 5}
    {:ok, island} = Island.new(:square, c)
    assert Enum.count(island.coordinates) == 4
  end


  test "returns {:error, :invalid_coordinate for stuff out of bounds}" do
    c = %Coordinate{row: 10, col: 10}
    assert {:error, :invalid_coordinate} = Island.new(:square, c)
  end

  test "guessing a hit" do
    c = %Coordinate{row: 5, col: 5}
    {:ok, island} = Island.new(:square, c)

    {:hit, %Island{hit_coordinates: hits}} = Island.guess(island, c)
    assert MapSet.member?(hits, c)
  end

  test "guessing a miss" do
    c = %Coordinate{row: 5, col: 5}
    {:ok, island} = Island.new(:square, c)

    m = %Coordinate{row: 0, col: 0}
    assert :miss == Island.guess(island, m)
  end

  test "forested" do
    f = %Island{
      coordinates: MapSet.new([%Coordinate{row: 1, col: 1}]),
      hit_coordinates: MapSet.new([%Coordinate{row: 1, col: 1}]),
    }

    assert Island.forested?(f) == true

    f = %Island{
      coordinates: MapSet.new([%Coordinate{row: 1, col: 1}]),
      hit_coordinates: MapSet.new([]),
    }

    assert Island.forested?(f) == false
  end

  test "overlaps" do
    a = %Island{
      coordinates: MapSet.new([%Coordinate{row: 1, col: 1}]),
      hit_coordinates: MapSet.new([]),
    }

    b = %Island{
      coordinates: MapSet.new([%Coordinate{row: 1, col: 1},
                               %Coordinate{row: 2, col: 2}]),
      hit_coordinates: MapSet.new([]),
    }

    assert Island.overlaps?(a, b) == true
  end
end
