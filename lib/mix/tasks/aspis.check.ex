defmodule Mix.Tasks.Aspis.Check do
  use Mix.Task

  alias Aspis.Utils

  @shortdoc "check project's dependencies for hidden code"

  # TODO dehardcode this
  @git_parent_directory "/tmp/aspis_repos"

  def run(args) do
    {:ok, _} = Aspis.check_required_programs()
    IO.inspect(args)
    {:ok, deps} = IO.inspect(Utils.get_project_deps())
    {:ok, hex_packages_from_mix_lock} = IO.inspect(Utils.get_packages_from_mix_lock())

    deps_names = Enum.map(deps, &elem(&1, 0))

    relevant_packages =
      hex_packages_from_mix_lock
      |> Enum.filter(fn package -> package.name in deps_names end)

    IO.inspect(relevant_packages)

    git_urls =
      relevant_packages
      |> Enum.map(fn package ->
        {package.name, Utils.get_github_git_url(package.hex_name)}
      end)
      |> Map.new()

    git_urls =
      git_urls
      |> Enum.map(fn {k, {:ok, v}} -> {k, v} end)
      |> Map.new()

    IO.inspect(git_urls)

    {:ok, project_deps_path} = Utils.get_project_deps_path()

    Enum.each(relevant_packages, fn package ->
      repo_path = IO.inspect(Path.join(@git_parent_directory, Atom.to_string(package.name)))
      dep_path = IO.inspect(Path.join(project_deps_path, Atom.to_string(package.name)))
      git_url = git_urls[package.name]
      Aspis.prepare_repo(git_url, repo_path)

      case Aspis.checkout_version_by_tag(package.version, repo_path) do
        {:ok, _} ->
          IO.inspect(Aspis.get_relevant_file_diffs(repo_path, dep_path))

        _ ->
          IO.puts("COULD NOT CHECKOUT THE RIGHT VERSION")
      end
    end)
  end
end
