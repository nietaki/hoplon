defmodule Support.Utils do
  def random_string(length \\ 12) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  def random_tmp_directory() do
    "/tmp/hoplon_tests/#{random_string()}"
  end

  # Mix task testing

  def get_output_lines(opts) do
    mock_io = Keyword.fetch!(opts, :io_device)
    output = StringIO.flush(mock_io)
    String.split(output, "\n", trim: true)
  end

  def mock_input_opts(user_inputs) do
    {:ok, mock_io} = StringIO.open(user_inputs)
    {:ok, mock_stderr} = StringIO.open("")
    [io_device: mock_io, stderr_device: mock_stderr]
  end
end
