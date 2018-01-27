defmodule IslandsEngineTest do
  use ExUnit.Case
  doctest IslandsEngine
  doctest IslandsEngine.Island, import: true

  test "greets the world" do
    assert IslandsEngine.hello() == :world
  end
end
