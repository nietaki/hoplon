defmodule Mix.Tasks.Hoplon.Check do
  use Mix.Task

  alias Hoplon.Utils
  alias Hoplon.CheckResult
  alias Hoplon.Lockfile
  alias Hoplon.HexPackage

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
         {:ok, hoplon_lock_path} <- Utils.get_hoplon_lock_path(),
         {:ok, project_deps_path} <- Utils.get_project_deps_path(),
         {:ok, project_deps} <- Utils.get_project_deps() do

      directly_used_package_names = Utils.get_deps_package_names(project_deps)
      relevant_packages = get_relevant_packages(directly_used_package_names, hex_packages_from_mix_lock)

      lockfile = Lockfile.read!(hoplon_lock_path)

      IO.puts(CheckResult.header_line())

      results =
        Enum.map(relevant_packages, fn package ->
          Task.async(fn ->
            Hoplon.check_package(package, @git_parent_directory, lockfile)
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

  @spec get_relevant_packages([atom()], [%HexPackage{}]) :: [%HexPackage{}]
  defp get_relevant_packages(used_package_names, mix_lock_packages) do
    # get all dependencies of the used packages iteratively until nothing more gets added
    further_dependencies =
      mix_lock_packages
      |> Enum.filter(fn %HexPackage{hex_name: name} -> name in used_package_names end)
      |> Enum.flat_map(fn %HexPackage{depends_on: depends_on} -> depends_on end)

    combined_dependencies = Enum.uniq(used_package_names ++ further_dependencies)

    if Enum.count(combined_dependencies) > Enum.count(used_package_names) do
      get_relevant_packages(combined_dependencies, mix_lock_packages)
    else
      # the dependency list stopped growing, let's return the right ones
      mix_lock_packages
      |> Enum.filter(fn %HexPackage{hex_name: name} -> name in combined_dependencies end)
    end
  end
end
