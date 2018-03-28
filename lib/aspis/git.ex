defmodule Aspis.Git do
  # ===========================================================================
  # API Functions
  # ===========================================================================

  def clone(git_url, path) do
    System.cmd("git", ["clone", git_url, path])
    |> cast_cmd_result()
  end

  def verify_remote(git_url, path) do
    remote_result = System.cmd("git", ["remote", "get-url", "origin"], cd: path)

    with {:ok, remote_url} <- cast_cmd_result(remote_result),
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

  # ===========================================================================
  # Helper Functions
  # ===========================================================================

  defp cast_cmd_result({result_text, 0}) do
    {:ok, result_text}
  end

  defp cast_cmd_result({result_text, status_code}) do
    {:error, {result_text, status_code}}
  end
end
