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

  defp example_deps_list() do
    # based on a true story
    [
      {:mix_test_watch, "~> 0.5", [only: :dev, runtime: false]},
      {:evil_left_pad, ">= 0.3.0"},
      {:hoplon, path: "/path/to/local/hoplon"},
      # this is also valid format https://hexdocs.pm/mix/Mix.Tasks.Deps.html
      {:ace, []},
      {:signex, github: "paywithcurl/signex", tag: "v1.5.2"},
      {:gettext, git: "https://github.com/elixir-lang/gettext.git", tag: "0.1"},
      {:uuid, "~> 1.7", hex: :uuid_erl}
    ]
  end

  describe "project_deps_hex_package_names" do
    test "skips the git - based dependencies" do
      names = get_deps_package_names(example_deps_list())
      refute :signex in names
      refute :gettext in names
    end

    test "skips the path - based dependencies" do
      names = get_deps_package_names(example_deps_list())
      refute :hoplon in names
    end

    test "uses hex package names instead of app names (if given)" do
      names = get_deps_package_names(example_deps_list())
      refute :uuid in names
      assert :uuid_erl in names
    end

    test "keeps the normal stuff" do
      names = get_deps_package_names(example_deps_list())
      assert :mix_test_watch in names
      assert :evil_left_pad in names
      assert :ace in names
    end
  end

  test "naive_pow is correct" do
    assert naive_pow(3, 2) == 9
    assert naive_pow(5, 1) == 5
    assert naive_pow(42, 0) == 1
    assert naive_pow(2, 10) == 1024
  end

  test "get_user_and_repo_name from github url" do
    url = "https://github.com/elixir-lang/ex_doc.git"
    assert {"elixir-lang", "ex_doc"} == get_user_and_repo_name(url)
  end
end
