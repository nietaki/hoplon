defmodule Aspis do
  alias Aspis.Git

  def prepare_repo(git_url, path) do
    with {:ok, _} <- Git.ensure_repo(git_url, path),
         {:ok, _} <- Git.arbitrary(["checkout", "master"], path),
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
end
