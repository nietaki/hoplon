defmodule Hoplon.CLI.GenericTask do
  @doc """
  Should return the valid actions for the task.

  If nil, means the task has no actions.
  """
  @callback valid_actions() :: [String.t()] | nil

  @doc """
  Should return the OptionParser.parse config for the task.

  The generic options will be added to it.
  """
  @callback option_parser_config() :: Keyword.t()

  @doc """
  Should return the default values for the task's switches, if
  they aren't provided in the command line arguments
  """
  @callback default_switch_values() :: Keyword.t()

  @doc """
  The function to be executed if the option parsing succeeds
  """
  @callback do_task(
              switches_with_default_values :: Keyword.t(),
              args :: [String.t()],
              opts :: Keyword.t()
            ) :: any()

  def run(task_module, argv, opts) do
    op_config = add_default_op_config(task_module.option_parser_config())

    valid_actions = task_module.valid_actions()

    case OptionParser.parse(argv, op_config) do
      {_parsed, _args, invalid = [_ | _]} ->
        msg = invalid_switches_message(invalid)
        Mix.raise(msg)

      {_parsed, [], []} ->
        Mix.raise(missing_action_message(valid_actions))

      {switches, args = [a | _rest], _invalid = []} ->
        if a in valid_actions do
          switches = add_default_switch_values(switches, task_module.default_switch_values())

          task_module.do_task(switches, args, opts)
        else
          Mix.raise(invalid_action_message(a, valid_actions))
        end
    end
  end

  ## Default values

  defp default_options() do
    [
      strict: [
        hoplon_env: :string,
        hoplon_dir: :string
      ],
      aliases: []
    ]
  end

  defp default_switch_values() do
    [
      hoplon_env: env_var_or_default("HOPLON_ENV", "default"),
      hoplon_dir: env_var_or_default("HOPLON_DIR", Path.expand("~/.hoplon"))
    ]
  end

  defp env_var_or_default(env_var_name, default) do
    case System.get_env(env_var_name) do
      empty when empty in [nil, ""] ->
        default

      value ->
        value
    end
  end

  ## Helper functions

  defp add_default_op_config(opts) do
    Keyword.merge(default_options(), opts, fn _k, v1, v2 -> Keyword.merge(v1, v2) end)
  end

  defp invalid_switches_message(invalid_switches = [_ | _]) do
    enumerated_switches =
      invalid_switches
      |> Enum.map(fn {k, _v} -> k end)
      |> splice()

    "Invalid switches: #{enumerated_switches}"
  end

  defp invalid_action_message(action, valid_actions) do
    "Invalid action '#{action}', expected one of (#{splice(valid_actions)})"
  end

  defp missing_action_message(valid_actions) do
    "Missing action, expected one of (#{splice(valid_actions)})"
  end

  defp add_default_switch_values(switches, task_default_values) do
    default_switch_values()
    |> Keyword.merge(task_default_values)
    |> Keyword.merge(switches)
  end

  defp splice(things) do
    Enum.join(things, ", ")
  end
end
