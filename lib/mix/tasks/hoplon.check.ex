defmodule Mix.Tasks.Hoplon.Check do
  use Mix.Task

  alias Hoplon.Utils
  alias Hoplon.CheckResult

  @shortdoc "Checks project's dependencies for hidden code"

  @moduledoc """
  Checks the project's dependencies for hidden code.

  Running this task will go through the project's dependencies, resolve
  where they're located on GitHub, clone each of their repos, check out
  the commit corresponding to the package version and screen the packages
  for any code differing from what is in the git repository.

  The idea is that while the GitHub repositories are constantly screened
  by the BEAM community, the published packages are rarely examined and
  it takes just one malicious maintainer to do a lot of damage.

  Running `$ mix hoplon.check` lets you screen for this form of attack.

  If `hoplon` finds suspicious differences in the code or fails to resolve
  the repository, the task will exit with a non-zero code.
  """

  # TODO dehardcode this
  @git_parent_directory "/tmp/hoplon_repos"

  @doc "Runs the task"
  def run(_args) do
    with {:ok, _} <- Hoplon.check_required_programs(),
         {:ok, hex_packages_from_mix_lock} <- Utils.get_packages_from_mix_lock(),
         {:ok, project_deps_path} <- Utils.get_project_deps_path() do
      # TODO figure out if all of those are necessarily used or packages get kept in mix_lock after they stop being used
      relevant_packages = hex_packages_from_mix_lock

      IO.puts(CheckResult.header_line())

      results =
        Stream.map(relevant_packages, fn package ->
          Task.async(fn ->
            Hoplon.check_package(package, @git_parent_directory)
          end)
        end)
        |> Stream.map(fn task ->
          Task.await(task, 120_000)
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

      Utils.task_exit(combined_exit_code)
    else
      {:error, reason} when is_atom(reason) ->
        Utils.task_exit(1, inspect(reason))
    end
  end
end
