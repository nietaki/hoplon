defmodule Mix.Tasks.Hoplon.StatusTest do
  alias Mix.Tasks.Hoplon.Status
  alias Mix.Tasks.Hoplon.TrustedKeys
  alias Hoplon.Crypto
  alias Hoplon.CLI.ConfigFile
  alias Hoplon.Data
  require Hoplon.Data
  alias Hoplon.CLI.Tools

  import Support.Utils

  use ExUnit.Case, async: false
  @moduletag timeout: 10_000
  @moduletag :current

  @password "1337_P455wort"
  # @comment "no comments!"
  # @verdict :safe
  @mix_lock_path "test/assets/simple.mix.lock"

  # @dialyxir_version "1.0.0-rc.6"
  @dialyxir_hash "78e97d9c0ff1b5521dd68041193891aebebce52fc3b93463c0a6806874557d7d"

  @dialyxir_package %Hoplon.HexPackage{
    depends_on: [:erlex],
    hash: "78e97d9c0ff1b5521dd68041193891aebebce52fc3b93463c0a6806874557d7d",
    hex_name: :dialyxir,
    name: :dialyxir,
    version: "1.0.0-rc.6"
  }

  @ex_doc_package %Hoplon.HexPackage{
    depends_on: [:earmark, :makeup_elixir],
    hash: "88eaa16e67c505664fd6a66f42ddb962d424ad68df586b214b71443c69887123",
    hex_name: :ex_doc,
    name: :ex_doc,
    version: "0.20.1"
  }

  @earmark_hash "b840562ea3d67795ffbb5bd88940b1bed0ed9fa32834915125ea7d02e35888a5"
  @ex_doc_hash "88eaa16e67c505664fd6a66f42ddb962d424ad68df586b214b71443c69887123"
  @makeup_elixir_hash "be7a477997dcac2e48a9d695ec730b2d22418292675c75aa2d34ba0909dcdeda"

  @tag :focus
  test "no audits present" do
    %{} = prepare_env_with_private_key()

    user_inputs = "\n"
    opts = mock_input_opts(user_inputs)

    reason = catch_exit(Status.run(["--mix-lock-file", @mix_lock_path], opts))
    # TODO good exit code
    assert {:shutdown, 13} = reason

    output_lines = get_output_lines(opts)
    IO.inspect(output_lines)
  end

  @tag :focus
  test "necessary audits present" do
    %{env_dir: env_dir} = prepare_env_with_private_key()

    user_inputs = "\n"
    opts = mock_input_opts(user_inputs)

    other_key = test_key()
    add_test_key_to_trusted_keys(env_dir, other_key)

    a = create_audit("earmark", @earmark_hash, :safe, other_key.fingerprint)
    {:ok, _} = store_signed_audit(env_dir, a, other_key)

    a = create_audit("ex_doc", @ex_doc_hash, :safe, other_key.fingerprint)
    {:ok, _} = store_signed_audit(env_dir, a, other_key)

    a = create_audit("makeup_elixir", @makeup_elixir_hash, :lgtm, other_key.fingerprint)
    {:ok, _} = store_signed_audit(env_dir, a, other_key)

    Status.run(["--mix-lock-file", @mix_lock_path], opts)

    output_lines = get_output_lines(opts)
    IO.inspect(output_lines)
  end

  describe "get_verified_audits_for_package" do
    @tag :focus
    test "picks up a correct signed audit" do
      %{env_dir: env_dir} = prepare_env_with_private_key()

      other_key = test_key()
      add_test_key_to_trusted_keys(env_dir, other_key)

      a = create_audit("dialyxir", @dialyxir_hash, :safe, other_key.fingerprint)
      {:ok, _} = store_signed_audit(env_dir, a, other_key)

      relevant_keys = %{other_key.fingerprint => other_key.public_key}

      assert [a.audit] ==
               Status.get_verified_audits_for_package(env_dir, @dialyxir_package, relevant_keys)

      assert [] == Status.get_verified_audits_for_package(env_dir, @ex_doc_package, relevant_keys)
    end
  end

  describe "verify_audit_matches_package" do
    test "returns ok when everything matches" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      audit = create_audit("dialyxir", @dialyxir_hash, :safe, fingerprint)

      assert :ok =
               Status.verify_audit_matches_package(audit.audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the fingerprint doesn't match" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      other_fingerprint = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
      audit = create_audit("dialyxir", @dialyxir_hash, :safe, other_fingerprint)

      assert {:error, :fingerprint_mismatch} =
               Status.verify_audit_matches_package(audit.audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the package name doesn't match" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      audit = create_audit("incorrect", @dialyxir_hash, :safe, fingerprint)

      assert {:error, :package_name_mismatch} =
               Status.verify_audit_matches_package(audit.audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the package hash doesn't match" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      audit = create_audit("dialyxir", "ldkfjlsfkjd", :safe, fingerprint)

      assert {:error, :package_hash_mismatch} =
               Status.verify_audit_matches_package(audit.audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the ecosystem isn't hexpm" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      a = create_audit("dialyxir", @dialyxir_hash, :safe, fingerprint)
      package = Data.package(a.package, ecosystem: "other_ecosystem")
      audit = Data.audit(a.audit, package: package)

      assert {:error, :invalid_ecosystem} =
               Status.verify_audit_matches_package(audit, @dialyxir_package, fingerprint)
    end
  end

  defp create_audit(package_name, package_hash, verdict, fingerprint) do
    kw = [
      name: package_name,
      version: "0.1.0",
      hash: package_hash,
      verdict: verdict,
      publicKeyFingerprint: fingerprint
    ]

    test_audit(kw)
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
