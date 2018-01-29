defmodule CoordinateTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias IslandsEngine.Coordinate

  test "it creates coordinates" do
    assert Coordinate.new(1,1) == {:ok, %Coordinate{row: 1, col: 1}}
  end


  property "it works for row and column 1-10" do
    range = StreamData.integer(1..10)
    check all row <- range,
      col <- range
      do
      assert {:ok, _} = Coordinate.new(row, col)
    end
  end

  property "it errors for other values" do
    range = StreamData.integer() |> StreamData.filter(&(&1 < 1 or &1 > 10))
    check all row <- range,
      col <- range
      do
      assert {:error, _} = Coordinate.new(row, col)
    end
  end

end
