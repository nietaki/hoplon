defmodule Hoplon.CLI.ConfigFileTest do
  use ExUnit.Case
  alias Hoplon.CLI.ConfigFile
  import Support.Utils

  @empty %{trusted_keys: []}

  test "new()" do
    assert @empty == ConfigFile.new()
    assert @empty == ConfigFile.new(%{})
    assert %{trusted_keys: [], foo: :bar} == ConfigFile.new(%{foo: :bar})
  end

  test "dumps lockfile struct to text correctly" do
    assert "%{trusted_keys: []}" == ConfigFile.to_string(@empty)
  end

  test "from_string()" do
    assert Map.merge(@empty, %{foo: %{}}) == ConfigFile.from_string("%{foo: %{}}")
  end

  describe "read_or_create!" do
    test "creates a default file if it doesn't exist" do
      path = "/tmp/#{random_string()}.exs"
      refute File.exists?(path)
      assert @empty == ConfigFile.read_or_create!(path)

      assert File.exists?(path)
    end

    test "does not modify an existing file" do
      path = "/tmp/#{random_string()}.exs"
      refute File.exists?(path)
      assert :ok == ConfigFile.write!(%{foo: :bar}, path)

      last_modified = File.lstat!(path).mtime
      assert Map.merge(@empty, %{foo: :bar}) == ConfigFile.read_or_create!(path)
      assert last_modified == File.lstat!(path).mtime
    end
  end
end
