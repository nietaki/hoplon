defmodule Mix.Tasks.Hoplon.Status do
  use Mix.Task

  alias Hoplon.CLI.GenericTask
  # alias Hoplon.CLI.Prompt
  alias Hoplon.Crypto
  alias Hoplon.CLI.Tools
  alias Hoplon.CLI.ConfigFile
  require Hoplon.Data
  alias Hoplon.Data
  alias Hoplon.Data.Encoder
  alias Hoplon.HexPackage
  alias Hoplon.CLI.Prompt

  @behaviour GenericTask

  @shortdoc "See the audit status of packages used in the project"

  @moduledoc """
  """

  @impl Mix.Task
  def run(argv, opts \\ []) do
    GenericTask.run(__MODULE__, argv, opts)
  end

  @impl GenericTask
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
  def do_task(switches, _args, opts) do
    mix_lock_path = Keyword.get(switches, :mix_lock_file)
    env_path = Tools.print_and_get_env_path(switches, opts)
    config_file_path = Tools.config_file_path(env_path)
    config = ConfigFile.read_or_create!(config_file_path)

    # TODO only get used packages, not all from mix lock
    packages =
      Hoplon.Utils.get_packages_from_mix_lock(mix_lock_path)
      |> Tools.extract_or_raise("could not read the mix.lock file from #{mix_lock_path}")

    trusted_keys = get_trusted_public_keys(env_path, config, true)

    package_audits =
      Enum.map(
        packages,
        fn p ->
          audits = get_verified_audits_for_package(env_path, p, trusted_keys)
          {p, audits}
        end
      )

    stats = Enum.map(package_audits, &package_stats(&1, switches))
    headers = ~w(name version dangerous_count suspicious_count lgtm_count safe_count)a
    rows = Enum.map(stats, fn map -> Enum.map(headers, &Map.get(map, &1)) end)
    Prompt.print_table(headers, rows, opts)

    if Enum.all?(package_audits, &package_accepted?(&1, switches)) do
      Prompt.puts("All packages accepted", opts)
      :ok
    else
      Prompt.puts("Some packages failed the check", opts)
      exit({:shutdown, 13})
    end
  end

  def package_stats({package = %Hoplon.HexPackage{}, audits}, _switches) do
    %{
      name: package.name,
      version: package.version,
      dangerous_count: get_verdict_count(audits, :dangerous),
      suspicious_count: get_verdict_count(audits, :suspicious),
      lgtm_count: get_verdict_count(audits, :lgtm),
      safe_count: get_verdict_count(audits, :safe)
    }
  end

  defp get_verdict_count(audits, verdict) when is_atom(verdict) do
    Enum.count(audits, fn audit -> Data.audit(audit, :verdict) == verdict end)
  end

  def package_accepted?({_package = %Hoplon.HexPackage{}, audits}, _switches) do
    # simple logic for now, should be configurable
    Enum.any?(audits, fn audit -> Data.audit(audit, :verdict) in [:safe, :lgtm] end)
  end

  # NOTE this is used in hoplon.fetch, edit with caution
  @spec get_trusted_public_keys(env_path :: String.t(), %{}, include_self? :: boolean) :: %{
          optional(String.t()) => tuple
        }
  def get_trusted_public_keys(env_path, config, include_self?) do
    my_key_part =
      case {include_self?, get_my_public_key(env_path)} do
        {false, _} ->
          %{}

        {true, nil} ->
          %{}

        {true, key} ->
          %{
            Crypto.get_fingerprint(key) => key
          }
      end

    trusted_keys =
      config.trusted_keys
      |> Enum.map(fn %{sha_256_fingerprint: f} -> f end)
      |> Enum.map(fn fingerprint ->
        {:ok, path} = Tools.get_peer_key_path(env_path, fingerprint)
        {:ok, pem} = File.read(path)
        {:ok, key} = Crypto.decode_public_key_from_pem(pem)
        actual_fingerprint = Crypto.get_fingerprint(key)

        if actual_fingerprint != fingerprint do
          Mix.raise("peer key under #{path} has an incorrect fingerprint - #{actual_fingerprint}")
        end

        {fingerprint, key}
      end)
      |> Map.new()

    Map.merge(trusted_keys, my_key_part)
  end

  def get_my_public_key(env_path) do
    public_key_path = Tools.public_key_path(env_path)

    if File.exists?(public_key_path) do
      pem = File.read!(public_key_path)
      {:ok, key} = Crypto.decode_public_key_from_pem(pem)
      key
    else
      nil
    end
  end

  def get_verified_audits_for_package(env_path, package, relevant_keys) do
    # keys is fingerprint -> public_key
    %HexPackage{hex_name: name, hash: hash} = package
    audit_dir = Tools.audit_dir(env_path, Atom.to_string(name), hash)

    if File.dir?(audit_dir) do
      {:ok, files} = File.ls(audit_dir)

      relevant_keys
      |> Enum.filter(fn {f, _k} ->
        "#{f}.audit" in files && "#{f}.sig" in files
      end)
      |> Enum.map(fn {f, k} ->
        audit = read_and_verify_audit_signature(audit_dir, f, k)
        :ok = verify_audit_matches_package(audit, package, f)
        audit
      end)
    else
      []
    end
  end

  defp read_and_verify_audit_signature(audit_dir, fingerprint, public_key) do
    ^fingerprint = Crypto.get_fingerprint(public_key)
    {:ok, audit_binary} = File.read(Path.join(audit_dir, "#{fingerprint}.audit"))
    {:ok, sig_binary} = File.read(Path.join(audit_dir, "#{fingerprint}.sig"))
    true = Crypto.verify_signature(audit_binary, sig_binary, public_key)

    {:ok, audit} = Encoder.decode(audit_binary, :Audit)

    audit
  end

  def verify_audit_matches_package(audit, package, expected_fingerprint) do
    %HexPackage{hex_name: name, hash: hash} = package
    audit_package = Data.audit(audit, :package)

    cond do
      Data.audit(audit, :publicKeyFingerprint) != expected_fingerprint ->
        {:error, :fingerprint_mismatch}

      Data.package(audit_package, :name) != Atom.to_string(name) ->
        {:error, :package_name_mismatch}

      Data.package(audit_package, :hash) != hash ->
        {:error, :package_hash_mismatch}

      Data.package(audit_package, :ecosystem) != "hexpm" ->
        {:error, :invalid_ecosystem}

      true ->
        :ok
    end
  end

  # defp nil_to_asn1_novalue(nil), do: :asn1_NOVALUE
  # defp nil_to_asn1_novalue(value), do: value
end
