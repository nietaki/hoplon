defmodule Mix.Tasks.Hoplon.MyKey do
  use Mix.Task

  alias Hoplon.CLI.GenericTask
  alias Hoplon.CLI.Prompt
  alias Hoplon.Crypto
  alias Hoplon.CLI.Tools

  @behaviour GenericTask

  @shortdoc "utilities for managing your private/public keypair"

  @moduledoc """
  Utilities for managing your public/private key pair

  ## Actions

  ### generate

  Generates your new public/private key pair. Will overwrite the current
  keypair, if one exists.

  The interactive tool will ask you for a password to protect the
  private key with.

      mix hoplon.my_key generate

  """

  @moduledoc GenericTask.generate_moduledoc(@moduledoc, [])

  @impl Mix.Task
  def run(argv, opts \\ []) do
    GenericTask.run(__MODULE__, argv, opts)
  end

  @impl GenericTask
  # def valid_actions(), do: ["generate", "show", "change_password"]
  def valid_actions(), do: ["generate"]

  @impl GenericTask
  def option_parser_config() do
    [
      strict: [],
      aliases: []
    ]
  end

  @impl GenericTask
  def default_switch_values() do
    []
  end

  @impl GenericTask
  def do_task(switches, ["generate" | _] = _args, opts) do
    env_path = Tools.print_and_get_env_path(switches, opts)

    private_key_file = Tools.private_key_path(env_path)
    public_key_file = Tools.public_key_path(env_path)

    if File.exists?(private_key_file) do
      sure? =
        Prompt.for_boolean(
          "#{private_key_file} already exists!\n> Do you want to delete it and generate a new one?",
          false,
          opts
        )

      if !sure? do
        Mix.raise("aborted")
      end
    end

    password = Prompt.for_password("Enter password for the key", opts)
    confirmation = Prompt.for_password("Confirm password for the key", opts)

    if password != confirmation do
      Mix.raise("Passwords don't match!")
    end

    Prompt.puts("Generating...", opts)

    {:ok, _private_key, public_key} = generate(env_path, password)
    fingerprint = Crypto.get_fingerprint(public_key)
    Prompt.puts("Your public key has been saved to #{public_key_file}", opts)
    Prompt.puts("Your key fingerprint is #{fingerprint}", opts)

    :ok
  end

  def generate(env_path, password) do
    private_key_file = Tools.private_key_path(env_path)
    public_key_file = Tools.public_key_path(env_path)
    private_key = Crypto.generate_private_key()
    public_key = Crypto.build_public_key(private_key)
    {:ok, encoded_private_key} = Crypto.encode_private_key_to_pem(private_key, password)
    {:ok, encoded_public_key} = Crypto.encode_public_key_to_pem(public_key)

    File.write!(private_key_file, encoded_private_key)
    File.write!(public_key_file, encoded_public_key)
    {:ok, private_key, public_key}
  end
end
