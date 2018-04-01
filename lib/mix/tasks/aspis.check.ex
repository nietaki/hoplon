defmodule Mix.Tasks.Aspis.Check do
  use Mix.Task

  alias Aspis.Utils
  alias Aspis.CheckResult

  @shortdoc "check project's dependencies for hidden code"

  # TODO dehardcode this
  @git_parent_directory "/tmp/aspis_repos"

  def run(_args) do
    with {:ok, _} <- Aspis.check_required_programs(),
         {:ok, deps} <- Utils.get_project_deps(),
         {:ok, hex_packages_from_mix_lock} <- Utils.get_packages_from_mix_lock(),
         {:ok, project_deps_path} <- Utils.get_project_deps_path() do
      deps_names = Enum.map(deps, &elem(&1, 0))

      # TODO figure out if all of those are necessarily used or packages get kept in mix_lock after they stop being used
      relevant_packages = hex_packages_from_mix_lock

      IO.puts(CheckResult.header_line())

      Stream.map(relevant_packages, fn package ->
        repo_path = Path.join(@git_parent_directory, Atom.to_string(package.name))
        dep_path = Path.join(project_deps_path, Atom.to_string(package.name))

        with result = CheckResult.new(package),
             {:ok, result} <- add_git_url(result),
             {:ok, _} <- Aspis.prepare_repo(result.git_url, repo_path),
             {:ok, result} <- checkout_version(result, repo_path),
             diffs = Aspis.get_relevant_file_diffs(repo_path, dep_path),
             result = %CheckResult{result | diffs: diffs} do
          result
        else
          {:error, result = %CheckResult{}} ->
            result
        end
      end)
      |> Stream.map(&CheckResult.representation_line/1)
      |> Enum.each(&IO.puts/1)
    else
      {:error, reason} when is_atom(reason) ->
        IO.puts("ERROR: #{reason}")
    end
  end

  defp add_git_url(result) do
    case Utils.get_github_git_url(result.hex_package.hex_name) do
      {:ok, git_url} ->
        {:ok, %CheckResult{result | git_url: git_url}}

      {:error, reason} ->
        {:error, CheckResult.set_error_reason(result, reason)}
    end
  end

  defp checkout_version(result, repo_path) do
    case Aspis.checkout_version_by_tag(result.hex_package.version, repo_path) do
      {:ok, version_tag} ->
        {:ok, %CheckResult{result | git_ref: {:tag, version_tag}}}

      {:error, {:invalid_ref, _}} ->
        {:error, CheckResult.set_error_reason(result, :could_not_find_git_tag)}
    end
  end
end
