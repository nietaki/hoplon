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

  test "absolve" do
    lf = Lockfile.absolve(@empty, :some_package, "some_hash", "my reason")

    assert %Lockfile{
             absolved: %{
               some_package: %{
                 "some_hash" => "my reason"
               }
             }
           } == lf

    lf = Lockfile.absolve(lf, :some_package, "other_hash", "other reason")

    assert %Lockfile{
             absolved: %{
               some_package: %{
                 "some_hash" => "my reason",
                 "other_hash" => "other reason"
               }
             }
           } == lf

    lf = Lockfile.absolve(lf, :other_package, "foo", "bar")

    assert lf.absolved[:other_package]["foo"] == "bar"
    assert lf.absolved[:some_package]["some_hash"] == "my reason"
  end
end
