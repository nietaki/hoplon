defmodule Mix.Tasks.Hoplon.MyKeyTest do
  alias Mix.Tasks.Hoplon.MyKey
  import Support.Utils

  use ExUnit.Case, async: false

  # if some input/output is incorrect in the test, it's going to
  # hang waiting for input and time out, let's make it faster
  @moduletag timeout: 5000

  @moduletag :current

  test "generating a new key where one doesn't exist before" do
    hoplon_dir = random_tmp_directory()
    System.put_env("HOPLON_DIR", hoplon_dir)

    user_inputs = """
    test%password
    test%password
    """

    opts = mock_input_opts(user_inputs)
    MyKey.run(["generate"], opts)

    assert [
             "hoplon_dir: #{hoplon_dir}",
             "hoplon_env: default",
             "Generating...",
             "DONE!"
           ] == get_output_lines(opts)

    private_keyfile = File.read!(Path.join(hoplon_dir, "default/my.private.pem"))
    assert private_keyfile =~ "BEGIN RSA PRIVATE KEY"
  end

  test "user aborting the operation when the key already exists" do
    assert_raise Mix.Error, "aborted", fn ->
      hoplon_dir = random_tmp_directory()
      System.put_env("HOPLON_DIR", hoplon_dir)
      env_dir = Path.join(hoplon_dir, "default")
      File.mkdir_p!(env_dir)
      File.touch!(Path.join(env_dir, "my.private.pem"))

      user_inputs = """
      n
      """

      opts = mock_input_opts(user_inputs)
      MyKey.run(["generate"], opts)
    end
  end

  test "user can overwrite an already existing keyfile if they decide to do so" do
    hoplon_dir = random_tmp_directory()
    System.put_env("HOPLON_DIR", hoplon_dir)
    env_dir = Path.join(hoplon_dir, "default")
    File.mkdir_p!(env_dir)
    File.touch!(Path.join(env_dir, "my.private.pem"))

    user_inputs = """
    y
    test%password
    test%password
    """

    opts = mock_input_opts(user_inputs)
    MyKey.run(["generate"], opts)

    assert [
             "hoplon_dir: #{hoplon_dir}",
             "hoplon_env: default",
             "Generating...",
             "DONE!"
           ] == get_output_lines(opts)

    private_keyfile = File.read!(Path.join(hoplon_dir, "default/my.private.pem"))
    assert private_keyfile =~ "BEGIN RSA PRIVATE KEY"
  end

  defp get_output_lines(opts) do
    mock_io = Keyword.fetch!(opts, :io_device)
    output = StringIO.flush(mock_io)
    String.split(output, "\n", trim: true)
  end

  defp mock_input_opts(user_inputs) do
    {:ok, mock_io} = StringIO.open(user_inputs)
    {:ok, mock_stderr} = StringIO.open("")
    [io_device: mock_io, stderr_device: mock_stderr]
  end
end
