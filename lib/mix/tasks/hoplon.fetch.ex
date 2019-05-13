defmodule Mix.Tasks.Hoplon.Fetch do
  use Mix.Task

  alias Hoplon.CLI.GenericTask
  alias Hoplon.CLI.Prompt
  alias Hoplon.Crypto
  alias Hoplon.CLI.Tools
  alias Hoplon.CLI.ConfigFile
  require Hoplon.Data
  alias Hoplon.Data.Encoder
  alias Hoplon.Data

  @behaviour GenericTask

  @shortdoc "fetch audits from the trusted keys from the server"

  @option_docs [
    "`--mix-lock-file` - uses a different lockfile than the main one for the project to look for used packages"
  ]

  @moduledoc """
  Fetches audits for the used packages, from the chosen server.

  Only fetches audits linked and signed by one of your trusted keys.

  ## Example

      mix hoplon.fetch

  """

  @moduledoc GenericTask.generate_moduledoc(@moduledoc, @option_docs)

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
  def do_task(switches, [] = _args, opts) do
    mix_lock_path = Keyword.get(switches, :mix_lock_file)
    env_path = Tools.print_and_get_env_path(switches, opts)
    config_file_path = Tools.config_file_path(env_path)
    config = ConfigFile.read_or_create!(config_file_path)

    packages =
      Hoplon.Utils.get_packages_from_mix_lock(mix_lock_path)
      |> Tools.extract_or_raise("could not read the mix.lock file from #{mix_lock_path}")

    # TODO change to false maybe?
    trusted_keys = Mix.Tasks.Hoplon.Status.get_trusted_public_keys(env_path, config, true)

    package_names_and_hashes =
      Enum.map(packages, fn package -> {"#{package.hex_name}", package.hash} end)

    Enum.map(package_names_and_hashes, fn name_and_hash ->
      fetch_and_write_audits(env_path, config, name_and_hash, trusted_keys, opts)
    end)
  end

  defp fetch_and_write_audits(env_path, config, {package_name, package_hash}, trusted_keys, opts) do
    fingerprints = Map.keys(trusted_keys)
    params = %{fingerprints: fingerprints}
    base = Map.get(config, :api_base_url, Hoplon.ApiClient.default_base_url())
    false = String.contains?(package_name, "/")
    false = String.contains?(package_hash, "/")
    path = "audits/fetch/hexpm/#{package_name}/#{package_hash}"

    case Hoplon.ApiClient.post(base, path, [], params) do
      {:ok, {200, _headers, %{"audits" => audits}}} ->
        Enum.each(audits, fn
          audit ->
            verify_and_save_audit(env_path, audit, trusted_keys, opts)
        end)

      other ->
        Prompt.puts(
          "could not fetch audits for #{package_name}/#{package_hash}: #{inspect(other)}",
          opts
        )
    end
  end

  def verify_and_save_audit(
        env_path,
        %{"encoded_audit" => audit_hex, "signature" => signature_hex},
        keys,
        opts
      ) do
    {:ok, audit_binary} = Crypto.hex_decode(audit_hex)
    {:ok, signature_binary} = Crypto.hex_decode(signature_hex)
    {:ok, audit} = Encoder.decode(audit_binary, :Audit)
    audit_fingerprint = Data.audit(audit, :publicKeyFingerprint)
    relevant_key = Map.fetch!(keys, audit_fingerprint)

    true = Crypto.verify_signature(audit_binary, signature_binary, relevant_key)

    package = Data.audit(audit, :package)
    package_name = Data.package(package, :name)
    package_hash = Data.package(package, :hash)
    audit_dir = Tools.audit_dir(env_path, package_name, package_hash)

    File.mkdir_p!(audit_dir)
    # TODO compare audit timestamps with potentially existing audit files
    # to make sure we're not overwriting newer audits with older ones
    audit_path = Tools.audit_path(env_path, package_name, package_hash, audit_fingerprint)
    sig_path = Tools.sig_path(env_path, package_name, package_hash, audit_fingerprint)

    File.write!(audit_path, audit_binary)
    File.write!(sig_path, signature_binary)

    Prompt.puts("saved #{audit_path}", opts)

    {:ok, :done}
  end
end
