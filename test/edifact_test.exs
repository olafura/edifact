defmodule EdifactTest do
  use ExUnit.Case
  doctest Edifact

  test "greets the world" do
    assert Edifact.hello() == :world
  end
end
