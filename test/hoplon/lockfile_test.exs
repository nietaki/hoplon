defmodule Hoplon.LockfileTest do
  use ExUnit.Case
  alias Hoplon.Lockfile

  @empty %Lockfile{
    absolved: %{}
  }

  test "new()" do
    assert %Lockfile{
             absolved: %{}
           } == Lockfile.new(%{absolved: %{}})
  end

  test "new() with empty arguments" do
    assert @empty == Lockfile.new(%{})
    assert @empty == Lockfile.new(nil)
    assert @empty == Lockfile.new()
  end

  test "dumps lockfile struct to text correctly" do
    # it doesn't get broken into multiple lines until it's longer
    assert "%{absolved: %{}}" == Lockfile.to_string(@empty)
  end

  test "from_string()" do
    assert %Lockfile{absolved: %{}} == Lockfile.from_string("%{absolved: %{}}")
  end
end
