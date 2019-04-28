defmodule Mix.Tasks.Hoplon.Status do
  use Mix.Task

  alias Hoplon.CLI.GenericTask
  alias Hoplon.CLI.Prompt
  alias Hoplon.Crypto
  alias Hoplon.CLI.Tools
  alias Hoplon.CLI.ConfigFile
  require Hoplon.Data
  alias Hoplon.Data

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
    _config = ConfigFile.read_or_create!(config_file_path)

    packages =
      Hoplon.Utils.get_packages_from_mix_lock(mix_lock_path)
      |> Tools.extract_or_raise("could not read the mix.lock file from #{mix_lock_path}")

    IO.inspect(packages)
  end

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

  defp nil_to_asn1_novalue(nil), do: :asn1_NOVALUE
  defp nil_to_asn1_novalue(value), do: value
end
