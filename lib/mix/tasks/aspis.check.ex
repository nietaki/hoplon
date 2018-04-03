defmodule Mix.Tasks.Aspis.Check do
  use Mix.Task

  alias Aspis.Utils
  alias Aspis.CheckResult

  @shortdoc "check project's dependencies for hidden code"

  # TODO dehardcode this
  @git_parent_directory "/tmp/aspis_repos"

  def run(_args) do
    with {:ok, _} <- Aspis.check_required_programs(),
         {:ok, hex_packages_from_mix_lock} <- Utils.get_packages_from_mix_lock(),
         {:ok, project_deps_path} <- Utils.get_project_deps_path() do
      # TODO figure out if all of those are necessarily used or packages get kept in mix_lock after they stop being used
      relevant_packages = hex_packages_from_mix_lock

      IO.puts(CheckResult.header_line())

      results =
        Stream.map(relevant_packages, fn package ->
          Aspis.check_package(package, @git_parent_directory)
        end)
        |> Stream.each(fn r ->
          r |> CheckResult.representation_line() |> IO.puts()
        end)
        |> Enum.to_list()

      combined_exit_code =
        results
        |> Enum.map(&CheckResult.get_status/1)
        |> Enum.map(&CheckResult.get_exit_code_from_status/1)
        |> Enum.reduce(&max/2)

      task_exit(combined_exit_code)
    else
      {:error, reason} when is_atom(reason) ->
        task_exit(1, inspect(reason))
    end
  end

  def task_exit(exit_code, message \\ nil) when is_integer(exit_code) do
    case {exit_code, message} do
      {_, nil} -> :ok
      {_, ""} -> :ok
      {0, msg} when is_binary(msg) -> IO.puts("OK: " <> msg)
      {_, msg} when is_binary(msg) -> IO.puts("ERROR: " <> msg)
    end

    exit({:shutdown, exit_code})
  end
end
