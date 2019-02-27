defmodule Mix.Tasks.Hoplon.Diff do
  use Mix.Task

  alias Hoplon.Diff
  alias Hoplon.CheckResult
  alias Hoplon.HexPackage
  alias Hoplon.Utils
  alias Hoplon.Lockfile

  @shortdoc "Shows differences between pulled package dependency and its github code"

  @moduledoc """
  Prints out the diff between the repository code and the hex package code
  for a given dependency.

      $ mix hoplon.diff <package_name>

  is equivalent to

      $ diff -r <package_code_directory> ./deps/<package_name>

  You can provide custom options to `mix hoplon.diff` - just add them after the package name.
  For example

      $ mix hoplon.diff ecto -ruN -x .git

  would translate to

      $ diff -ruN -x .git <ecto_repo_dir> ./deps/ecto

  The task will forward the exit code of the `diff` call, which means if the directories
  do differ, the task will exit with a non-zero code.
  """

  @doc "Runs the task"
  def run([package_name | additional_args]) do
    repos_parent_directory = Utils.get_repos_parent_path()

    with {:ok, _} <- Hoplon.check_required_programs(),
         {:ok, hex_packages} <- Utils.get_packages_from_mix_lock(),
         {:ok, package} <- choose_hex_package(hex_packages, package_name),
         {:ok, project_deps_path} <- Utils.get_project_deps_path(),
         {:ok, hoplon_lock_path} <- Utils.get_hoplon_lock_path(),
         # FIXME a good amount of code below is duplicated and it shouldn't depend on CheckResult
         repo_path = Path.join(repos_parent_directory, Atom.to_string(package.name)),
         dep_path = Path.join(project_deps_path, Atom.to_string(package.name)),
         lockfile = Lockfile.read!(hoplon_lock_path),
         result = Hoplon.check_package(package, repos_parent_directory, lockfile) do
      case result do
        %CheckResult{git_url: nil} ->
          Utils.task_exit(11, "could not find package's github repo")

        %CheckResult{git_ref: nil} ->
          Utils.task_exit(11, "could not find package's git ref")

        %CheckResult{} ->
          {output, exit_code} = Diff.diff_dirs_raw(repo_path, dep_path, additional_args)
          IO.write(output)
          Utils.task_exit(exit_code)
      end
    else
      {:error, reason} when is_atom(reason) ->
        Utils.task_exit(1, inspect(reason))
    end
  end

  def run(_) do
    Utils.task_exit(1, "USAGE: $ mix hoplon.diff <package_name>")
  end

  defp choose_hex_package(hex_packages, name) do
    case Enum.find(hex_packages, &HexPackage.has_name?(&1, name)) do
      nil ->
        {:error, :hex_package_not_found_in_dependencies}

      package ->
        {:ok, package}
    end
  end
end
