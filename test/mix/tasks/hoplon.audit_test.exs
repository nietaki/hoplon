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
  @moduletag :current

  @password "1337_P455wort"
  @comment "no comments!"
  @verdict :safe
  @mix_lock_path "test/assets/sample.mix.lock"
  @dialyxir_version "1.0.0-rc.6"
  @dialyxir_hash "78e97d9c0ff1b5521dd68041193891aebebce52fc3b93463c0a6806874557d7d"

  test "happy path" do
    %{fingerprint: fingerprint, public_key_path: public_key_path} = prepare_env_with_private_key()

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
    {:ok, public_key} = File.read!(public_key_path) |> Crypto.decode_public_key_from_pem()
    assert Crypto.verify_signature(audit_binary, sig_binary, public_key)
    refute Crypto.verify_signature(audit_binary <> "1", sig_binary, public_key)
  end

  defp prepare_env_with_private_key() do
    env_dir = prepare_fresh_hoplon_env()

    user_inputs = """
    #{@password}
    #{@password}
    """

    opts = mock_input_opts(user_inputs)

    # this depends on the other task a bit, but it's the cleanest simple solution, I think
    alias Mix.Tasks.Hoplon.MyKey
    MyKey.run(["generate"], opts)
    output_lines = get_output_lines(opts)

    [
      "Your public key has been saved to " <> public_key_path,
      "Your key fingerprint is " <> fingerprint
    ] = Enum.take(output_lines, -2)

    %{
      env_dir: env_dir,
      fingerprint: fingerprint,
      public_key_path: public_key_path
    }
  end
end
