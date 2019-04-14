defmodule Mix.Tasks.Hoplon.MyKey do
  use Mix.Task

  alias Hoplon.CLI.Options
  alias Hoplon.CLI.Utils

  @shortdoc "utilities for managing user's private/public keypair"

  @moduledoc """
  """

  @actions ["generate", "show", "change_password"]

  def run(argv) do
    opts = Options.add_defaults(task_options())

    case IO.inspect(OptionParser.parse(argv, opts)) do
      {_parsed, _args, invalid = [_ | _]} ->
        msg = Options.invalid_switches_message(invalid)
        Utils.task_exit(1, msg)

      {_parsed, [], []} ->
        Utils.task_exit(1, Options.missing_action_message(@actions))

      {_parsed, [a | _rest], _invalid = []} when a in @actions ->
        :ok

      {_parsed, [invalid_action | _rest], _invalid = []} ->
        Utils.task_exit(1, Options.invalid_action_message(invalid_action, @actions))
    end
  end

  defp task_options() do
    []
  end
end
