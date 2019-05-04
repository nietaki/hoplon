defmodule Hoplon.CLI.ToolsTest do
  use ExUnit.Case
  alias Hoplon.CLI.Tools
  import Support.Utils

  describe "bootstrap_hoplon_env/2" do
    test "will create an empty environment in a deeply nested non-existing directory" do
      path = "/tmp/#{random_string()}/#{random_string()}/"
      env_name = random_string(6)
      env_path = Path.join(path, env_name)

      assert {:ok, ^env_path} = Tools.bootstrap_hoplon_env(path, env_name)

      assert File.dir?(env_path)
      assert File.dir?(env_path <> "/peer_keys")
      assert File.dir?(env_path <> "/audits")
      assert File.regular?(env_path <> "/config.exs")
    end

    test "doesn't touch already created files" do
      path = "/tmp/#{random_string()}"
      env_name = random_string(6)

      assert {:ok, env_path} = Tools.bootstrap_hoplon_env(path, env_name)
      last_modified = File.lstat!(env_path).mtime
      File.write!(env_path <> "/foo.bar", "some_content")

      assert {:ok, env_path} = Tools.bootstrap_hoplon_env(path, env_name)
      assert File.regular?(env_path <> "/foo.bar")
      assert last_modified == File.lstat!(env_path).mtime
    end

    test "does not let you use an invalid env name" do
      path = "/tmp/#{random_string()}"
      assert {:error, :invalid_env_name} = Tools.bootstrap_hoplon_env(path, "foo/bar")
      assert {:error, :invalid_env_name} = Tools.bootstrap_hoplon_env(path, "łóżeczko")
      assert {:error, :invalid_env_name} = Tools.bootstrap_hoplon_env(path, "foo.bar")
      assert {:ok, _} = Tools.bootstrap_hoplon_env(path, "foobar")
      assert {:ok, _} = Tools.bootstrap_hoplon_env(path, "foo_bar")
    end
  end
end
