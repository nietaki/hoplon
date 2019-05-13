defmodule Mix.Tasks.Hoplon.TrustedKeys do
  use Mix.Task

  alias Hoplon.CLI.GenericTask
  alias Hoplon.CLI.Prompt
  alias Hoplon.Crypto
  alias Hoplon.CLI.Tools
  alias Hoplon.CLI.ConfigFile

  @behaviour GenericTask

  @shortdoc "utilities for managing the keys you trust"

  @option_docs [
    "`--nickname` / `-n` - give the trusted key a nickname"
  ]

  @moduledoc """
  Utilities for managing trusted keys.

  ## Actions

  ### add

  Adds a `.pem` file to the collection of trusted keys. A nickname can be specified for it

  Example:

      mix hoplon.trusted_keys add path/to/some_public_key.pem --nickname Steve

  ### remove

  Removes an existing key from the collection of trusted keys.

  The argument can be either the key's fingerprint or the nickname you gave it

  Example:

      mix hoplon.trusted_keys remove Steve
      mix hoplon.trusted_keys remove 367b857bec55185e81b5ec618ee06060684ef66ee400a94feac1b6c2c28d08b0

  ### list

  Lists all trusted keys, with their nicknames.
  """

  @moduledoc GenericTask.generate_moduledoc(@moduledoc, @option_docs)

  @impl Mix.Task
  def run(argv, opts \\ []) do
    GenericTask.run(__MODULE__, argv, opts)
  end

  @impl GenericTask
  # TODO show and download
  def valid_actions(), do: ~w(add remove list)

  # Option:
  # option, aliases
  @impl GenericTask
  def option_parser_config() do
    [
      strict: [{:nickname, :string}],
      aliases: [{:n, :nickname}]
    ]
  end

  @impl GenericTask
  def default_switch_values() do
    []
  end

  @impl GenericTask
  def do_task(switches, ["list" | _] = _args, opts) do
    env_path = Tools.print_and_get_env_path(switches, opts)
    config_file_path = Tools.config_file_path(env_path)
    config = ConfigFile.read_or_create!(config_file_path)
    trusted_keys = Map.get(config, :trusted_keys, [])
    headers = ["fingerprint", "name"]

    rows =
      trusted_keys
      |> Enum.map(fn key ->
        [
          Map.get(key, :sha_256_fingerprint),
          Map.get(key, :nickname)
        ]
      end)
      |> Enum.sort()

    Prompt.print_table(headers, rows, opts)
  end

  def do_task(switches, ["add", path] = _args, opts) do
    env_path = Tools.print_and_get_env_path(switches, opts)

    with Prompt.puts("Reading public key at #{path}...", opts),
         {:ok, public_key_pem} <- File.read(path),
         Prompt.puts("Decoding from PEM format...", opts),
         {:ok, fingerprint} <- add_pem_to_peer_keys(env_path, public_key_pem),
         Prompt.puts("Decoded, the sha256 fingerprint is #{fingerprint}", opts),
         maybe_nickname = Keyword.get(switches, :nickname),
         {:ok, _} <- add_trusted_key_fingerprint_to_config(env_path, fingerprint, maybe_nickname) do
      config_file_path = Tools.config_file_path(env_path)
      Prompt.puts("Trusted key added to #{config_file_path}", opts)
      :ok
    else
      {:error, reason} ->
        Mix.raise(inspect(reason))
    end
  end

  def do_task(switches, ["remove", fingerprint_or_name] = _args, opts) do
    env_path = Tools.print_and_get_env_path(switches, opts)
    config_file_path = Tools.config_file_path(env_path)
    config = ConfigFile.read_or_create!(config_file_path)

    trusted_keys = Map.get(config, :trusted_keys, [])

    our_key? = fn key ->
      Map.get(key, :sha_256_fingerprint) == fingerprint_or_name ||
        Map.get(key, :nickname) == fingerprint_or_name
    end

    {removed_keys, remaining_keys} = Enum.split_with(trusted_keys, our_key?)

    case removed_keys do
      [%{sha_256_fingerprint: fingerprint}] ->
        Prompt.puts("Removing trusted key with fingerprint #{fingerprint}", opts)
        config = Map.put(config, :trusted_keys, remaining_keys)
        ConfigFile.write!(config, config_file_path)

      [] ->
        Prompt.puts("No matching keys to remove", opts)
    end

    :ok
  end

  # TODO list next, to get the infrastructure for getting out the trusted keys
  # next, get similar infrastructure for getting valid audits for: {[{package, hash | :all}] | :all, [fingerprint] | :all}
  # (that should do the verification)

  def add_trusted_key_fingerprint_to_config(env_path, fingerprint, maybe_nickname) do
    config_file_path = Tools.config_file_path(env_path)
    config = ConfigFile.read_or_create!(config_file_path)
    trusted_keys = Map.get(config, :trusted_keys, [])

    key_entry = %{sha_256_fingerprint: fingerprint}

    key_entry =
      case maybe_nickname do
        nil ->
          key_entry

        nickname when is_binary(nickname) ->
          Map.put(key_entry, :nickname, nickname)
      end

    trusted_keys =
      [key_entry | trusted_keys]
      |> Enum.uniq_by(& &1.sha_256_fingerprint)

    config = Map.put(config, :trusted_keys, trusted_keys)
    ConfigFile.write!(config, config_file_path)
    {:ok, config}
  end

  def add_pem_to_peer_keys(env_path, public_key_pem) do
    with {:ok, public_key} <- Crypto.decode_public_key_from_pem(public_key_pem),
         fingerprint = Crypto.get_fingerprint(public_key, :sha256),
         {:ok, target_key_path} = Tools.get_peer_key_path(env_path, fingerprint),
         :ok <- File.write(target_key_path, public_key_pem, [:write]) do
      {:ok, fingerprint}
    end
  end
end
