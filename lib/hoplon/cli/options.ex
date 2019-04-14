defmodule Hoplon.CLI.Options do
  def add_defaults(opts) do
    Keyword.merge(default_options(), opts, fn _k, v1, v2 -> Keyword.merge(v1, v2) end)
  end

  defp default_options() do
    [
      strict: [
        env: :string,
        hoplon_dir: :string
      ],
      aliases: []
    ]
  end

  def invalid_switches_message(invalid_switches = [_ | _]) do
    enumerated_switches =
      invalid_switches
      |> Enum.map(fn {k, _v} -> k end)
      |> splice()

    "Invalid switches: #{enumerated_switches}"
  end

  def invalid_action_message(action, valid_actions) do
    "Invalid action '#{action}', expected one of (#{splice(valid_actions)})"
  end

  def missing_action_message(valid_actions) do
    "Missing action, expected one of (#{splice(valid_actions)})"
  end

  defp splice(things) do
    Enum.join(things, ", ")
  end
end
