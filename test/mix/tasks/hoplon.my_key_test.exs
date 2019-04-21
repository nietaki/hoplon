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
