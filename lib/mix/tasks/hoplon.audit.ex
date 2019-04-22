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
    {:ok, packages} = Hoplon.Utils.get_packages_from_mix_lock(mix_lock_path)

    package = Enum.find(packages, fn package -> "#{package.hex_name}" == package_name end)
    IO.inspect(package)

    found_text = if package, do: "found in your mix.lock", else: "NOT found in your mix.lock"
    Prompt.puts("You're about to audit package '#{package_name}', #{found_text}", opts)

    default_version = get_prop(package, :version)
    package_version = Prompt.for_string_with_default("Package version", default_version, opts)
    maybe_complain_about_nil(package_version, "package version")

    default_hash = get_prop(package, :hash)
    package_hash = Prompt.for_string_with_default("Package hash", default_hash, opts)
    maybe_complain_about_nil(package_hash, "package hash")

    IO.inspect({package_name, package_version, package_hash})

    verdict_options = ~w(dangerous suspicious lgtm safe nil)a
    verdict = Prompt.for_enum("What's the verdict?", verdict_options, opts)
    IO.inspect(verdict)

    author? = Prompt.for_boolean("Are you the author of the package?", false, opts)

    comment =
      Prompt.for_string("Comment for the audit", opts)
      |> empty_string_to_nil()

    IO.inspect(comment)

    private_key_path = Tools.private_key_path(env_path)
    password = Prompt.for_password("Enter password to unlock #{private_key_path}", opts)
    {:ok, pem_contents} = File.read(private_key_path)
    {:ok, private_key} = Crypto.decode_private_key_from_pem(pem_contents, password)
    public_key = Crypto.build_public_key(private_key)
    fingerprint = Crypto.get_fingerprint(public_key)

    # TODO summary table maybe?
    package =
      Data.package(
        name: package_name,
        version: package_version,
        hash: package_hash
      )

    IO.inspect(package)

    timestamp = :os.system_time(:seconds)
    IO.inspect(timestamp)

    audit =
      Data.audit(
        package: package,
        verdict: nil_to_asn1_novalue(verdict),
        comment: nil_to_asn1_novalue(comment),
        publicKeyFingerprint: fingerprint,
        createdAt: timestamp,
        auditedByAuthor: author?
      )

    IO.inspect(audit)

    {:ok, encoded_audit} = Data.Encoder.encode(audit)
    IO.inspect(encoded_audit)

    signature = Crypto.get_signature(encoded_audit, private_key)
    IO.inspect(signature)
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
