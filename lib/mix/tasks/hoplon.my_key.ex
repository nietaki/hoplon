defmodule Mix.Tasks.Hoplon.MyKey do
  use Mix.Task

  alias Hoplon.CLI.GenericTask
  alias Hoplon.CLI.Prompt
  alias Hoplon.Crypto
  alias Hoplon.CLI.Tools

  @behaviour GenericTask

  @shortdoc "utilities for managing user's private/public keypair"

  @moduledoc """
  """

  @impl Mix.Task
  def run(argv, opts \\ []) do
    GenericTask.run(__MODULE__, argv, opts)
  end

  @impl GenericTask
  def valid_actions(), do: ["generate", "show", "change_password"]

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
    hoplon_dir = Keyword.fetch!(switches, :hoplon_dir)
    hoplon_env = Keyword.fetch!(switches, :hoplon_env)
    Prompt.puts("hoplon_dir: #{hoplon_dir}", opts)
    Prompt.puts("hoplon_env: #{hoplon_env}", opts)
    {:ok, _} = Tools.bootstrap_hoplon_env!(hoplon_dir, hoplon_env)
    private_key_file = Path.join([hoplon_dir, hoplon_env, "my.private.pem"])
    public_key_file = Path.join([hoplon_dir, hoplon_env, "my.public.pem"])

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
      IO.inspect({password, confirmation})
      Mix.raise("Passwords don't match!")
    end

    Prompt.puts("Generating...", opts)

    private_key = Crypto.generate_private_key()
    public_key = Crypto.build_public_key(private_key)
    {:ok, encoded_private_key} = Crypto.encode_private_key_to_pem(private_key, password)
    {:ok, encoded_public_key} = Crypto.encode_public_key_to_pem(public_key)

    File.write!(private_key_file, encoded_private_key)
    File.write!(public_key_file, encoded_public_key)

    Prompt.puts("DONE!", opts)

    :ok
  end
end
