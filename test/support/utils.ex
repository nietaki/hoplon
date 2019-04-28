defmodule Support.Utils do
  def random_string(length \\ 12) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
    |> String.replace("-", "_")
  end

  def random_tmp_directory() do
    "/tmp/hoplon_tests/#{random_string(16)}"
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

  def prepare_fresh_hoplon_env() do
    hoplon_dir = random_tmp_directory()
    env_name = random_string(10)
    System.put_env("HOPLON_DIR", hoplon_dir)
    System.put_env("HOPLON_ENV", env_name)
    {:ok, env_path} = Hoplon.CLI.Tools.bootstrap_hoplon_env(hoplon_dir, env_name)
    env_path
  end

  def generate_random_public_key() do
    alias Hoplon.Crypto
    private_key = Crypto.generate_private_key()
    public_key = Crypto.build_public_key(private_key)

    fingerprint = Crypto.get_fingerprint(public_key)
    {:ok, public_pem} = Crypto.encode_public_key_to_pem(public_key)
    dir = "/tmp/hoplon_tests/random_public_keys"
    File.mkdir_p!(dir)

    key_name = "#{random_string()}.pem"
    path = Path.join(dir, key_name)
    File.write!(path, public_pem)
    {fingerprint, path, public_pem}
  end
end
