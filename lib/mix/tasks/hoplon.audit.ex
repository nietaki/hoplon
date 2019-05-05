defmodule Mix.Tasks.Hoplon.Audit do
  use Mix.Task

  alias Hoplon.CLI.GenericTask
  alias Hoplon.CLI.Prompt
  alias Hoplon.Crypto
  alias Hoplon.CLI.Tools
  alias Hoplon.CLI.ConfigFile
  require Hoplon.Data
  alias Hoplon.Data

  @behaviour GenericTask

  @shortdoc "Create (and upload) a new package audit"

  @moduledoc """
  """

  @impl Mix.Task
  def run(argv, opts \\ []) do
    GenericTask.run(__MODULE__, argv, opts)
  end

  @impl GenericTask
  # TODO show and download
  def valid_actions(), do: nil

  @impl GenericTask
  def option_parser_config() do
    [
      strict: [
        mix_lock_file: :string
      ],
      aliases: []
    ]
  end

  @impl GenericTask
  def default_switch_values() do
    []
  end

  @impl GenericTask
  def do_task(switches, [package_name | _] = _args, opts) do
    mix_lock_path = Keyword.get(switches, :mix_lock_file)
    env_path = Tools.print_and_get_env_path(switches, opts)
    config_file_path = Tools.config_file_path(env_path)
    _config = ConfigFile.read_or_create!(config_file_path)

    packages =
      Hoplon.Utils.get_packages_from_mix_lock(mix_lock_path)
      |> Tools.extract_or_raise("could not read the mix.lock file from #{mix_lock_path}")

    package = Enum.find(packages, fn package -> "#{package.hex_name}" == package_name end)

    found_text = if package, do: "found in your mix.lock", else: "NOT found in your mix.lock"
    Prompt.puts("You're about to audit package '#{package_name}', #{found_text}", opts)

    private_key_path = Tools.private_key_path(env_path)

    pem_contents =
      File.read(private_key_path)
      |> Tools.extract_or_raise("Can't read your private key from #{private_key_path}")

    default_version = get_prop(package, :version)
    package_version = Prompt.for_string_with_default("Package version", default_version, opts)
    maybe_complain_about_nil(package_version, "package version")

    default_hash = get_prop(package, :hash)
    package_hash = Prompt.for_string_with_default("Package hash", default_hash, opts)
    maybe_complain_about_nil(package_hash, "package hash")

    # TODO add options to provide these from cli
    verdict_options = ~w(dangerous suspicious lgtm safe nil)a
    verdict = Prompt.for_enum("What's the verdict?", verdict_options, opts)

    author? = Prompt.for_boolean("Are you the author of the package?", false, opts)

    comment =
      Prompt.for_string("Comment for the audit", opts)
      |> empty_string_to_nil()

    password = Prompt.for_password("Enter password to unlock #{private_key_path}", opts)

    private_key =
      Crypto.decode_private_key_from_pem(pem_contents, password)
      |> Tools.extract_or_raise("could not unlock the private key with this password")

    public_key = Crypto.build_public_key(private_key)
    fingerprint = Crypto.get_fingerprint(public_key)

    # TODO summary table maybe?
    package =
      Data.package(
        name: package_name,
        version: package_version,
        hash: package_hash
      )

    timestamp = DateTime.utc_now() |> DateTime.to_unix(:second)

    audit =
      Data.audit(
        package: package,
        verdict: nil_to_asn1_novalue(verdict),
        comment: nil_to_asn1_novalue(comment),
        publicKeyFingerprint: fingerprint,
        createdAt: timestamp,
        auditedByAuthor: author?
      )

    encoded_audit =
      Data.Encoder.encode(audit)
      |> Tools.extract_or_raise("could not encode the audit")

    signature = Crypto.get_signature(encoded_audit, private_key)
    {:ok, _} = create_audit_files(env_path, audit, encoded_audit, signature)

    # TODO upload? Y/n
    # TODO configurable api client for tests
    # TODO url configurable in the environment

    # uploading audit
    audit_hex = Crypto.hex_encode!(encoded_audit)
    signature_hex = Crypto.hex_encode!(signature)
    {:ok, public_key_pem} = Crypto.encode_public_key_to_pem(public_key)

    params = %{
      audit_hex: audit_hex,
      signature_hex: signature_hex,
      public_key_pem: public_key_pem
    }

    base = "https://hoplon-server.gigalixirapp.com"

    {:ok, {200, _headers, _body}} = Hoplon.ApiClient.post(base, "audits/upload", [], params)

    audit_path = Tools.audit_path(env_path, package_name, package_hash, fingerprint)
    Prompt.puts("Audit saved to #{audit_path}", opts)
  end

  def create_audit_files(env_path, audit, encoded_audit, signature) do
    fingerprint = Data.audit(audit, :publicKeyFingerprint)
    package = Data.audit(audit, :package)
    package_name = Data.package(package, :name)
    package_hash = Data.package(package, :hash)
    audit_dir = Tools.audit_dir(env_path, package_name, package_hash)

    File.mkdir_p!(audit_dir)
    audit_path = Tools.audit_path(env_path, package_name, package_hash, fingerprint)
    sig_path = Tools.sig_path(env_path, package_name, package_hash, fingerprint)

    File.write!(audit_path, encoded_audit)
    File.write!(sig_path, signature)

    {:ok, :done}
  end

  defp maybe_complain_about_nil(nil, label) do
    Mix.raise("You need to provide a value for `#{label}`")
  end

  defp maybe_complain_about_nil(_value, _label) do
    :ok
  end

  defp get_prop(nil, _prop) do
    nil
  end

  defp get_prop(%Hoplon.HexPackage{} = package, prop) do
    Map.get(package, prop)
  end

  defp empty_string_to_nil(empty) when empty in ["", nil] do
    nil
  end

  defp empty_string_to_nil(str) when is_binary(str) do
    str
  end

  defp nil_to_asn1_novalue(nil), do: :asn1_NOVALUE
  defp nil_to_asn1_novalue(value), do: value
end
