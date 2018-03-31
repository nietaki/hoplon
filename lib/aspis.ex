defmodule Aspis do
  alias Aspis.Diff
  alias Aspis.Git
  alias Aspis.Utils

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
         {:ok, _} <- Git.arbitrary(["pull", "origin", "master"], path),
         {:ok, _} <- Git.arbitrary(["fetch", "--tags"], path) do
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
