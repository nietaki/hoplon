defmodule Aspis do
  alias Aspis.Diff
  alias Aspis.Git
  alias Aspis.Utils
  alias Aspis.HexPackage
  alias Aspis.CheckResult

  @program_dependencies ["git", "diff"]

  def check_required_programs() do
    missing_programs =
      @program_dependencies
      |> Enum.reject(&Utils.program_exists?/1)

    case missing_programs do
      [] -> {:ok, :all_required_programs_present}
      missing_programs -> {:error, {:missing_required_programs, missing_programs}}
    end
  end

  def prepare_repo(git_url, path) do
    with {:ok, _} <- Git.ensure_repo(git_url, path),
         {:ok, _} <- Git.arbitrary(["checkout", "--quiet", "master"], path),
         {:ok, _} <- Git.arbitrary(["pull", "--quiet", "origin", "master"], path),
         {:ok, _} <- Git.arbitrary(["fetch", "--quiet", "--tags"], path) do
      {:ok, :repo_prepared}
    end
  end

  def checkout_version_by_tag(version, cd_path) do
    case Git.attempt_checkout(version, cd_path) do
      success = {:ok, _} ->
        success

      {:error, _} ->
        Git.attempt_checkout("v" <> version, cd_path)
    end
  end

  def check_package(package = %HexPackage{}, git_parent_directory) do
    {:ok, project_deps_path} = Utils.get_project_deps_path()
    repo_path = Path.join(git_parent_directory, Atom.to_string(package.name))
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

  def get_relevant_file_diffs(baseline_dir, dependency_dir) do
    all_diffs = Diff.diff_files_in_directories(baseline_dir, dependency_dir)

    all_diffs
    |> Enum.reject(fn diff ->
      case diff do
        # extra stuff in the repo
        {:only_in_left, _} ->
          true

        # things hex puts in
        {:only_in_right, ".hex"} ->
          true

        {:only_in_right, ".fetch"} ->
          true

        {:only_in_right, "hex_metadata.config"} ->
          true

        {:only_in_right, relative_path} ->
          if Path.basename(relative_path) == ".DS_Store" do
            true
          else
            false
          end

        # the rest is relevant
        _ ->
          false
      end
    end)
  end
end
