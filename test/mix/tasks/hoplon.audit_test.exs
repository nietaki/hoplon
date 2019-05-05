defmodule Mix.Tasks.Hoplon.AuditTest do
  alias Mix.Tasks.Hoplon.Audit
  alias Hoplon.Crypto
  alias Hoplon.Data.Encoder
  alias Hoplon.Data
  require Hoplon.Data
  require Record

  import Support.Utils

  use ExUnit.Case, async: false
  @moduletag timeout: 10_000
  @moduletag :audit

  @password "1337_P455wort"
  @comment "no comments!"
  @verdict :safe
  @mix_lock_path "test/assets/sample.mix.lock"
  @dialyxir_version "1.0.0-rc.6"
  @dialyxir_hash "78e97d9c0ff1b5521dd68041193891aebebce52fc3b93463c0a6806874557d7d"

  test "happy path" do
    %{
      fingerprint: fingerprint,
      public_key: public_key
    } = prepare_env_with_private_key()

    before = DateTime.utc_now() |> DateTime.to_unix(:second)

    user_input_lines = [
      # package version
      "",
      # package hash
      "",
      "#{@verdict}",
      # author?
      "n",
      "#{@comment}",
      "#{@password}",
      # just making sure there's a newline at the end
      ""
    ]

    user_inputs = Enum.join(user_input_lines, "\n")

    opts = mock_input_opts(user_inputs)
    Audit.run(["dialyxir", "--mix-lock-file", @mix_lock_path], opts)
    output_lines = get_output_lines(opts)

    assert [
             _hoplon_dir,
             _hoplon_env,
             "You're about to audit package 'dialyxir', found in your mix.lock",
             "Audit saved to " <> audit_path
           ] = output_lines

    sig_path = String.replace_suffix(audit_path, ".audit", ".sig")

    assert File.exists?(audit_path)
    audit_binary = File.read!(audit_path)
    assert {:ok, audit} = Encoder.decode(audit_binary, :Audit)

    assert Record.is_record(audit)
    assert Data.audit(audit, :comment) == @comment
    now = DateTime.utc_now() |> DateTime.to_unix(:second)
    audit_time = Data.audit(audit, :createdAt)
    assert before <= audit_time
    assert audit_time <= now
    assert Data.audit(audit, :publicKeyFingerprint) == fingerprint
    assert Data.audit(audit, :auditedByAuthor) == false
    assert Data.audit(audit, :verdict) == @verdict

    package = Data.audit(audit, :package)
    assert Data.package(package, :ecosystem) == "hexpm"
    assert Data.package(package, :name) == "dialyxir"
    assert Data.package(package, :version) == @dialyxir_version
    assert Data.package(package, :hash) == @dialyxir_hash

    audit_binary = File.read!(audit_path)
    sig_binary = File.read!(sig_path)
    assert Crypto.verify_signature(audit_binary, sig_binary, public_key)
    refute Crypto.verify_signature(audit_binary <> "1", sig_binary, public_key)
  end

  test "correct error when the private key does not exist" do
    env_dir = prepare_fresh_hoplon_env()
    expected_message = "Can't read your private key from " <> Path.join(env_dir, "my.private.pem")

    assert_raise Mix.Error, expected_message, fn ->
      user_inputs = "\n"
      opts = mock_input_opts(user_inputs)
      Audit.run(["dialyxir", "--mix-lock-file", @mix_lock_path], opts)
    end
  end

  defp prepare_env_with_private_key() do
    alias Hoplon.CLI.Tools
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
