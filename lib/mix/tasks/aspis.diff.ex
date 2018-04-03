defmodule Mix.Tasks.Aspis.Diff do
  use Mix.Task

  alias Aspis.Diff
  alias Aspis.CheckResult
  alias Aspis.HexPackage
  alias Aspis.Utils

  @shortdoc "show differences between pulled package dependency and its github code"

  # TODO dehardcode this
  @git_parent_directory "/tmp/aspis_repos"


  def run([package_name]) do
    with {:ok, _} <- Aspis.check_required_programs(),
         {:ok, hex_packages} <- Utils.get_packages_from_mix_lock(),
         {:ok, package} <- choose_hex_package(hex_packages, package_name),
         {:ok, project_deps_path} <- Utils.get_project_deps_path(),
         # FIXME a good amount of code below is duplicated and it shouldn't depend on CheckResult
         repo_path = Path.join(@git_parent_directory, Atom.to_string(package.name)),
         dep_path = Path.join(project_deps_path, Atom.to_string(package.name)),
         result = Aspis.check_package(package, @git_parent_directory) do
      case result do
        %CheckResult{git_url: nil} ->
          Utils.task_exit(11, "could not find package's github repo")

        %CheckResult{git_ref: nil} ->
          Utils.task_exit(11, "could not find package's git ref")

        %CheckResult{} ->
          {output, exit_code} = Diff.diff_dirs_raw(repo_path, dep_path)
          IO.write(output)
          Utils.task_exit(exit_code)
      end
    else
      {:error, reason} when is_atom(reason) ->
        Utils.task_exit(1, inspect(reason))
    end
  end


  def run(_) do
    Utils.task_exit(1, "run mix aspis.check with the name of the package as the argument")
  end


  def choose_hex_package(hex_packages, name) do
    case Enum.find(hex_packages, &HexPackage.has_name?(&1, name)) do
      nil ->
        {:error, :hex_package_not_found_in_dependencies}
      package -> {:ok, package}
    end
  end
end
