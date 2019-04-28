defmodule Mix.Tasks.Hoplon.MyKeyTest do
  alias Mix.Tasks.Hoplon.MyKey
  import Support.Utils

  use ExUnit.Case, async: false

  # if some input/output is incorrect in the test, it's going to
  # hang waiting for input and time out, let's make it faster
  @moduletag timeout: 10_000

  test "generating a new key where one doesn't exist before" do
    env_dir = prepare_fresh_hoplon_env()

    user_inputs = """
    test%password
    test%password
    """

    opts = mock_input_opts(user_inputs)
    MyKey.run(["generate"], opts)

    assert [
             "hoplon_dir: " <> hoplon_dir,
             "hoplon_env: " <> hoplon_env,
             "Generating...",
             "Your public key has been saved to " <> public_key_path,
             "Your key fingerprint is " <> _fingerprint
           ] = get_output_lines(opts)

    assert env_dir == Path.join(hoplon_dir, hoplon_env)

    assert public_key_path == Path.join(env_dir, "my.public.pem")

    private_keyfile = File.read!(Path.join(env_dir, "my.private.pem"))
    assert private_keyfile =~ "BEGIN RSA PRIVATE KEY"
  end

  test "user aborting the operation when the key already exists" do
    assert_raise Mix.Error, "aborted", fn ->
      env_dir = prepare_fresh_hoplon_env()
      File.touch!(Path.join(env_dir, "my.private.pem"))

      user_inputs = """
      n
      """

      opts = mock_input_opts(user_inputs)
      MyKey.run(["generate"], opts)
    end
  end

  test "user can overwrite an already existing keyfile if they decide to do so" do
    env_dir = prepare_fresh_hoplon_env()
    File.touch!(Path.join(env_dir, "my.private.pem"))

    user_inputs = """
    y
    test%password
    test%password
    """

    opts = mock_input_opts(user_inputs)
    MyKey.run(["generate"], opts)

    assert [
             "hoplon_dir: " <> hoplon_dir,
             "hoplon_env: " <> hoplon_env,
             "Generating...",
             _public_key_location_info,
             _fingerprint_info
           ] = get_output_lines(opts)

    private_keyfile = File.read!(Path.join(env_dir, "my.private.pem"))
    assert private_keyfile =~ "BEGIN RSA PRIVATE KEY"
  end
end
