defmodule AspisTest do
  use ExUnit.Case
  doctest Aspis

  test "greets the world" do
    assert Aspis.hello() == :world
  end
end
