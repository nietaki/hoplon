defmodule Hoplon.CLI.Options do
  def parse_options_and_continue(task_module, argv, opts) do
    alias Hoplon.CLI.Utils
    op_config = add_default_op_config(task_module.option_parser_config())

    valid_actions = task_module.valid_actions()

    case OptionParser.parse(argv, op_config) do
      {_parsed, _args, invalid = [_ | _]} ->
        msg = invalid_switches_message(invalid)
        Utils.task_exit(1, msg)

      {_parsed, [], []} ->
        Utils.task_exit(1, missing_action_message(valid_actions))

      {switches, args = [a | _rest], _invalid = []} ->
        if a in valid_actions do
          switches = add_default_switch_values(switches, task_module.default_switch_values())

          task_module.do_task(switches, args, opts)
        else
          Utils.task_exit(1, invalid_action_message(a, valid_actions))
        end
    end
  end

  ## Default values

  defp default_options() do
    [
      strict: [
        env: :string,
        hoplon_dir: :string
      ],
      aliases: []
    ]
  end

  defp default_switch_values() do
    []
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
