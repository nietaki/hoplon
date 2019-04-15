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
end
