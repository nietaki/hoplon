defmodule Mix.Tasks.Hoplon.StatusTest do
  alias Mix.Tasks.Hoplon.Audit
  alias Mix.Tasks.Hoplon.Status
  alias Mix.Tasks.Hoplon.TrustedKeys
  alias Hoplon.Crypto
  alias Hoplon.CLI.ConfigFile
  alias Hoplon.Data.Encoder
  alias Hoplon.Data
  require Hoplon.Data
  # require Record
  alias Hoplon.CLI.Tools

  import Support.Utils

  use ExUnit.Case, async: false
  @moduletag timeout: 10_000
  @moduletag :current

  @password "1337_P455wort"
  # @comment "no comments!"
  # @verdict :safe
  # @mix_lock_path "test/assets/sample.mix.lock"

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

  # test "happy path" do
  #   %{
  #     env_dir: env_dir,
  #     public_key: public_key,
  #     fingerprint: fingerprint
  #   } = prepare_env_with_private_key()

  #   user_inputs = "\n"
  #   opts = mock_input_opts(user_inputs)

  #   Status.run(["--mix-lock-file", @mix_lock_path], opts)
  #   output_lines = get_output_lines(opts)
  #   flunk "TODO assertions"
  # end

  describe "get_verified_audits_for_package" do
    test "picks up a correct signed audit" do
      %{env_dir: env_dir} = prepare_env_with_private_key()

      {fingerprint, other_private_key, other_public_key} = generate_a_key()
      {:ok, public_pem} = Crypto.encode_public_key_to_pem(other_public_key)

      {:ok, _} = TrustedKeys.add_trusted_key_fingerprint_to_config(env_dir, fingerprint, nil)
      {:ok, _} = TrustedKeys.add_pem_to_peer_keys(env_dir, public_pem)

      audit = create_audit("dialyxir", @dialyxir_hash, :safe, fingerprint)
      {:ok, encoded_audit} = Encoder.encode(audit)
      signature = Crypto.get_signature(encoded_audit, other_private_key)

      {:ok, _} = Audit.create_audit_files(env_dir, audit, encoded_audit, signature)
      relevant_keys = %{fingerprint => other_public_key}

      assert [audit] ==
               Status.get_verified_audits_for_package(env_dir, @dialyxir_package, relevant_keys)

      assert [] == Status.get_verified_audits_for_package(env_dir, @ex_doc_package, relevant_keys)
    end
  end

  describe "verify_audit_matches_package" do
    test "returns ok when everything matches" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      audit = create_audit("dialyxir", @dialyxir_hash, :safe, fingerprint)

      assert :ok = Status.verify_audit_matches_package(audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the fingerprint doesn't match" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      other_fingerprint = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
      audit = create_audit("dialyxir", @dialyxir_hash, :safe, other_fingerprint)

      assert {:error, :fingerprint_mismatch} =
               Status.verify_audit_matches_package(audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the package name doesn't match" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      audit = create_audit("incorrect", @dialyxir_hash, :safe, fingerprint)

      assert {:error, :package_name_mismatch} =
               Status.verify_audit_matches_package(audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the package hash doesn't match" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      audit = create_audit("dialyxir", "ldkfjlsfkjd", :safe, fingerprint)

      assert {:error, :package_hash_mismatch} =
               Status.verify_audit_matches_package(audit, @dialyxir_package, fingerprint)
    end

    test "returns an error when the ecosystem isn't hexpm" do
      fingerprint = "b8448188d5656d9cdad8a6bf32d1ec390716fe12d6e66cc0722cd2576425474a"
      audit = create_audit("dialyxir", @dialyxir_hash, :safe, fingerprint)
      package = Data.audit(audit, :package)
      package = Data.package(package, ecosystem: "other_ecosystem")
      audit = Data.audit(audit, package: package)

      assert {:error, :invalid_ecosystem} =
               Status.verify_audit_matches_package(audit, @dialyxir_package, fingerprint)
    end
  end

  defp create_audit(package_name, package_hash, verdict, fingerprint) do
    package =
      Data.package(ecosystem: "hexpm", name: package_name, version: "0.1.0", hash: package_hash)

    Data.audit(
      package: package,
      verdict: verdict,
      comment: "comment",
      publicKeyFingerprint: fingerprint,
      createdAt: 1_554_670_254,
      auditedByAuthor: false
    )
  end

  defp generate_a_key() do
    private_key = Crypto.generate_private_key()
    public_key = Crypto.build_public_key(private_key)

    fingerprint = Crypto.get_fingerprint(public_key)
    {fingerprint, private_key, public_key}
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
