defmodule Mix.Tasks.Hoplon.TrustedKeysTest do
  alias Mix.Tasks.Hoplon.TrustedKeys
  import Support.Utils

  use ExUnit.Case, async: false
  @moduletag timeout: 10_000

  describe "add action" do
    test "adding a trusted key" do
      {fingerprint, key_path, public_pem} = generate_random_public_key()
      env_dir = prepare_fresh_hoplon_env()

      user_inputs = ""

      opts = mock_input_opts(user_inputs)
      TrustedKeys.run(["add", key_path], opts)
      _output_lines = get_output_lines(opts)

      peer_keys_path = Path.join(env_dir, "peer_keys")
      config_path = Path.join(env_dir, "config.exs")

      assert File.read!("#{peer_keys_path}/#{fingerprint}.public.pem") == public_pem
      new_config = Hoplon.CLI.ConfigFile.read_or_create!(config_path)

      assert %{
               trusted_keys: [
                 %{
                   sha_256_fingerprint: fingerprint
                 }
               ]
             } == new_config
    end

    test "adding a trusted key with a nickname" do
      env_dir = prepare_fresh_hoplon_env()

      {fingerprint, key_path, public_pem} = generate_random_public_key()

      user_inputs = ""

      opts = mock_input_opts(user_inputs)
      TrustedKeys.run(["add", key_path, "--nickname", "foobar"], opts)
      _output_lines = get_output_lines(opts)

      peer_keys_path = Path.join(env_dir, "peer_keys")
      config_path = Path.join(env_dir, "config.exs")

      assert File.read!("#{peer_keys_path}/#{fingerprint}.public.pem") == public_pem
      new_config = Hoplon.CLI.ConfigFile.read_or_create!(config_path)

      assert %{
               trusted_keys: [
                 %{
                   sha_256_fingerprint: fingerprint,
                   nickname: "foobar"
                 }
               ]
             } == new_config
    end

    test "adding a trusted key a second time overrides the old one" do
      env_dir = prepare_fresh_hoplon_env()

      {fingerprint, key_path, public_pem} = generate_random_public_key()

      user_inputs = ""

      opts = mock_input_opts(user_inputs)
      TrustedKeys.run(["add", key_path, "--nickname", "foobar"], opts)
      TrustedKeys.run(["add", key_path], opts)

      peer_keys_path = Path.join(env_dir, "peer_keys")
      config_path = Path.join(env_dir, "config.exs")

      assert File.read!("#{peer_keys_path}/#{fingerprint}.public.pem") == public_pem
      new_config = Hoplon.CLI.ConfigFile.read_or_create!(config_path)

      assert %{
               trusted_keys: [
                 %{
                   sha_256_fingerprint: fingerprint
                 }
               ]
             } == new_config
    end

    test "trying to add an invalid key" do
      env_dir = prepare_fresh_hoplon_env()

      assert_raise Mix.Error, fn ->
        user_inputs = ""
        opts = mock_input_opts(user_inputs)

        File.mkdir_p!("/tmp/hoplon_tests/")
        key_path = "/tmp/hoplon_tests/incorrect_key.pem"
        File.write(key_path, "this is not what a pem key looks like")

        TrustedKeys.run(["add", key_path], opts)
      end

      config_path = Path.join(env_dir, "config.exs")
      unmodified_config = Hoplon.CLI.ConfigFile.read_or_create!(config_path)
      assert %{trusted_keys: []} == unmodified_config
    end
  end

  describe "remove action" do
    test "removing a non-existing key is a no-op with a message" do
      {fingerprint, key_path, _public_pem} = generate_random_public_key()
      env_dir = prepare_fresh_hoplon_env()
      opts = mock_input_opts("")
      TrustedKeys.run(["add", key_path, "-n", "foobar"], opts)

      config_path = Path.join(env_dir, "config.exs")

      opts = mock_input_opts("")
      TrustedKeys.run(["remove", "not_there"], opts)
      output_lines = get_output_lines(opts)
      assert [_, _, "No matching keys to remove"] = output_lines

      assert %{
               trusted_keys: [
                 %{sha_256_fingerprint: fingerprint, nickname: "foobar"}
               ]
             } == Hoplon.CLI.ConfigFile.read_or_create!(config_path)
    end

    test "removing an existing key by fingerprint" do
      {fingerprint, key_path, _public_pem} = generate_random_public_key()
      env_dir = prepare_fresh_hoplon_env()
      opts = mock_input_opts("")
      TrustedKeys.run(["add", key_path, "-n", "foobar"], opts)

      config_path = Path.join(env_dir, "config.exs")

      opts = mock_input_opts("")
      TrustedKeys.run(["remove", fingerprint], opts)

      assert %{trusted_keys: []} == Hoplon.CLI.ConfigFile.read_or_create!(config_path)

      output_lines = get_output_lines(opts)
      assert [_, _, "Removing trusted key with fingerprint " <> ^fingerprint] = output_lines
    end

    test "removing an existing key by nickname" do
      {fingerprint, key_path, _public_pem} = generate_random_public_key()
      env_dir = prepare_fresh_hoplon_env()
      opts = mock_input_opts("")
      TrustedKeys.run(["add", key_path, "-n", "foobar"], opts)

      config_path = Path.join(env_dir, "config.exs")

      opts = mock_input_opts("")
      TrustedKeys.run(["remove", "foobar"], opts)

      assert %{trusted_keys: []} == Hoplon.CLI.ConfigFile.read_or_create!(config_path)

      output_lines = get_output_lines(opts)
      assert [_, _, "Removing trusted key with fingerprint " <> ^fingerprint] = output_lines
    end
  end

  describe "list action" do
    test "displays both fingerprints and names" do
      _env_dir = prepare_fresh_hoplon_env()
      {fingerprint, key_path, _public_pem} = generate_random_public_key()

      user_inputs = ""

      opts = mock_input_opts(user_inputs)
      TrustedKeys.run(["add", key_path, "--nickname", "my friend"], opts)

      opts = mock_input_opts(user_inputs)
      TrustedKeys.run(["list"], opts)

      output_lines = get_output_lines(opts)

      assert [
               _hoplon_dir,
               _hoplon_env,
               "| fingerprint                                                      | name      |",
               "| ---------------------------------------------------------------- | --------- |",
               last_row
             ] = output_lines

      assert "| #{fingerprint} | my friend |" == last_row
    end
  end

  defp generate_random_public_key() do
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
