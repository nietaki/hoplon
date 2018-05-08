defmodule Hoplon.GitTest do
  alias Hoplon.Git
  alias TestSupport.Tools

  use ExUnit.Case
  @moduletag :integration

  @evil_left_pad_git_url "https://github.com/nietaki/hoplon.git"

  describe "ensure_repo" do
    test "works with an existing repo" do
      dir = Tools.create_new_temp_directory()
      assert {:ok, _} = Git.ensure_repo(@evil_left_pad_git_url, dir)

      assert {:ok, status_text} = Git.arbitrary(["status"], dir)
      assert status_text =~ "On branch master"
    end

    test "works with a non-existing repo" do
      dir = Tools.create_new_temp_directory()
      dir = Path.join(dir, "foo/bar")

      assert {:ok, _} = Git.ensure_repo(@evil_left_pad_git_url, dir)

      assert {:ok, status_text} = Git.arbitrary(["status"], dir)
      assert status_text =~ "On branch master"
    end

    test "returns an error if there are files in the provided directory" do
      dir = Tools.create_new_temp_directory()
      File.write!(Path.join(dir, "foo.txt"), "file's contents")

      assert {:error, :directory_occupied} = Git.ensure_repo(@evil_left_pad_git_url, dir)

      assert ["foo.txt"] == File.ls!(dir)
    end
  end

  describe "get_github_user_and_package_from_git_url" do
    @describetag integration: false

    test "simple case" do
      assert {:ok, {"nietaki", "hoplon"}} =
               Git.get_github_user_and_package_from_git_url(
                 "https://github.com/nietaki/hoplon.git"
               )
    end
  end
end
