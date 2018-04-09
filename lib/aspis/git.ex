defmodule Aspis.Git do
  @moduledoc false

  alias Aspis.Utils

  # ===========================================================================
  # API Functions
  # ===========================================================================

  def clone(git_url, path) do
    Utils.cmd("git", ["clone", "--quiet", git_url, path])
  end

  def verify_remote(git_url, path) do
    remote_result = arbitrary(["remote", "get-url", "origin"], path)

    with {:ok, remote_url} <- remote_result,
         {:ok, ^git_url} <- {:ok, String.trim(remote_url)} do
      {:ok, git_url}
    else
      _ ->
        {:error, :invalid_remote_url}
    end
  end

  def purge_repo(path) do
    if is_empty_directory(path) || is_repo_directory(path) do
      File.rm_rf(path)
      {:ok, :purged}
    else
      {:error, :not_a_repo_directory}
    end
  end

  def is_empty_directory(path) do
    case File.ls(path) do
      {:ok, []} -> true
      _ -> false
    end
  end

  def is_repo_directory(path) do
    with {:ok, items} <- File.ls(path),
         true <- ".git" in items do
      true
    else
      _ ->
        false
    end
  end

  def ensure_repo(git_url, path) do
    with :ok <- File.mkdir_p(path) do
      ensure_correct_repo_in_directory(git_url, path)
    end
  end

  defp ensure_correct_repo_in_directory(git_url, path) do
    case {is_empty_directory(path), is_repo_directory(path)} do
      {true, _} ->
        clone(git_url, path)

      {false, true} ->
        case verify_remote(git_url, path) do
          res = {:ok, _} ->
            res

          {:error, :invalid_remote_url} ->
            {:ok, _} = purge_repo(path)
            clone(git_url, path)
        end

      {false, false} ->
        {:error, :directory_occupied}
    end
  end

  def get_head_tags(cd_path) do
    with {:ok, head_sha} <- arbitrary(["rev-parse", "HEAD"], cd_path),
         head_sha = String.trim(head_sha),
         {:ok, tag_tuples} <- get_tags(cd_path) do
      head_tags =
        tag_tuples
        |> Enum.filter(fn {sha, _tag} -> sha == head_sha end)
        |> Enum.map(fn {_sha, tag} -> tag end)

      {:ok, head_tags}
    end
  end

  def get_tags(cd_path) do
    res =
      case arbitrary(["show-ref", "--tags"], cd_path) do
        {:ok, str} -> {:ok, str}
        {:error, {"", _}} -> {:ok, ""}
        other -> other
      end

    with {:ok, lines_string} <- res do
      res =
        lines_string
        |> String.split(~r/(\r\n\|\r|\n)/, trim: true)
        |> Enum.map(fn line -> String.split(line, " ", parts: 2) end)
        |> Enum.map(fn [sha, tag] -> {sha, String.trim_leading(tag, "refs/tags/")} end)

      {:ok, res}
    end
  end

  def arbitrary(args, cd_path) when is_list(args) and is_binary(cd_path) do
    Utils.cmd("git", args, cd_path)
  end

  def attempt_checkout(treeish, cd_path) when is_binary(treeish) do
    case Utils.cmd("git", ["checkout", "--quiet", treeish], cd_path, stderr_to_stdout: true) do
      {:ok, _} ->
        {:ok, treeish}

      {:error, _} ->
        {:error, {:invalid_ref, treeish}}
    end
  end

  # NOTE: this doesn't really validate the git url
  def get_github_user_and_package_from_git_url(git_url) when is_binary(git_url) do
    case Regex.run(~r{([\w_-]+)/([\w_-]+).git$}, git_url) do
      [_whole, user, repo_name] ->
        {:ok, {user, repo_name}}

      _other ->
        {:error, :could_not_parse_repo_url}
    end
  end
end
