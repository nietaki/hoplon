defmodule Mix.Tasks.Hoplon.StatusTest do
  alias Mix.Tasks.Hoplon.Status
  alias Mix.Tasks.Hoplon.TrustedKeys
  alias Hoplon.Crypto
  alias Hoplon.CLI.ConfigFile
  # alias Hoplon.Data.Encoder
  # alias Hoplon.Data
  # require Hoplon.Data
  # require Record
  alias Hoplon.CLI.Tools

  import Support.Utils

  use ExUnit.Case, async: false
  @moduletag timeout: 10_000
  @moduletag :current

  @password "1337_P455wort"
  # @comment "no comments!"
  # @verdict :safe
  @mix_lock_path "test/assets/sample.mix.lock"
  # @dialyxir_version "1.0.0-rc.6"
  # @dialyxir_hash "78e97d9c0ff1b5521dd68041193891aebebce52fc3b93463c0a6806874557d7d"

  @moduletag :focus
  test "happy path" do
    %{
      env_dir: env_dir,
      public_key: public_key,
      fingerprint: fingerprint
    } = prepare_env_with_private_key()

    user_inputs = "\n"
    opts = mock_input_opts(user_inputs)

    Status.run(["--mix-lock-file", @mix_lock_path], opts)
    output_lines = get_output_lines(opts)
  end

  describe "get_trusted_public_keys" do
    test "with just the public_key present" do
      %{
        env_dir: env_dir,
        public_key: public_key,
        fingerprint: fingerprint
      } = prepare_env_with_private_key()

      config_path = Tools.config_file_path(env_dir)
      config = ConfigFile.read_or_create!(config_path)

      assert %{} == Status.get_trusted_public_keys(env_dir, config, false)
      assert %{fingerprint => public_key} == Status.get_trusted_public_keys(env_dir, config, true)
    end

    test "shows other keys too" do
      %{
        env_dir: env_dir,
        public_key: my_public_key,
        fingerprint: my_fingerprint
      } = prepare_env_with_private_key()

      {fingerprint, _, public_pem} = generate_random_public_key()
      {:ok, other_public_key} = Crypto.decode_public_key_from_pem(public_pem)

      {:ok, _} = TrustedKeys.add_trusted_key_fingerprint_to_config(env_dir, fingerprint, nil)
      {:ok, _} = TrustedKeys.add_pem_to_peer_keys(env_dir, public_pem)

      config_path = Tools.config_file_path(env_dir)
      config = ConfigFile.read_or_create!(config_path)

      assert %{fingerprint => other_public_key} ==
               Status.get_trusted_public_keys(env_dir, config, false)

      assert %{my_fingerprint => my_public_key, fingerprint => other_public_key} ==
               Status.get_trusted_public_keys(env_dir, config, true)
    end
  end

  defp prepare_env_with_private_key() do
    alias Mix.Tasks.Hoplon.MyKey
    env_dir = prepare_fresh_hoplon_env()

    {:ok, _private_key, public_key} = MyKey.generate(env_dir, @password)
    public_key_path = Tools.public_key_path(env_dir)
    fingerprint = Crypto.get_fingerprint(public_key)

    %{
      env_dir: env_dir,
      fingerprint: fingerprint,
      public_key: public_key,
      public_key_path: public_key_path
    }
  end
end
