defmodule Hoplon.UtilsTest do
  use ExUnit.Case

  import Hoplon.Utils

  @repo_url "https://github.com/nietaki/hoplon"

  describe "github_regex" do
    test "works in a simple case" do
      assert [@repo_url] == Regex.run(github_regex(), @repo_url)
    end

    test "works with some extra garbage at the end" do
      assert [@repo_url] == Regex.run(github_regex(), @repo_url <> "?what")
      assert [@repo_url] == Regex.run(github_regex(), @repo_url <> "&foo=bar")
      assert [@repo_url] == Regex.run(github_regex(), @repo_url <> "#myelixirstatus")
      assert [@repo_url] == Regex.run(github_regex(), @repo_url <> " after space")
    end

    test "deals with dashes, dots and underscores" do
      repo_url = "https://github.com/foo_bar/baz-ban.ex"
      assert [repo_url] == Regex.run(github_regex(), repo_url)
    end

    test "deals with random capitalizations and digits" do
      repo_url = "https://github.com/JamesBond007/DEADBEEF"
      assert [repo_url] == Regex.run(github_regex(), repo_url)
    end
  end
end
