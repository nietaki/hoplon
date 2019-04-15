defmodule Mix.Tasks.Hoplon.MyKey do
  use Mix.Task

  alias Hoplon.CLI.Options
  alias Hoplon.CLI.GenericTask

  @behaviour GenericTask

  @shortdoc "utilities for managing user's private/public keypair"

  @moduledoc """
  """

  @impl Mix.Task
  def run(argv, opts \\ []) do
    Options.parse_options_and_continue(__MODULE__, argv, opts)
  end

  @impl GenericTask
  def valid_actions(), do: ["generate", "show", "change_password"]

  @impl GenericTask
  def option_parser_config() do
    []
  end

  @impl GenericTask
  def default_switch_values() do
    []
  end

  @impl GenericTask
  def do_task(switches, args, _opts) do
    IO.inspect(switches)
    IO.inspect(args)
    IO.write("foo \nbar:")
    user_input = IO.read(:line)
    IO.inspect(user_input)
    :ok
  end
end
