defmodule Mix.Tasks.Aspis.Check do
  use Mix.Task

  alias Aspis.Utils

  @shortdoc "check project's dependencies for hidden code"

  # TODO dehardcode this
  @git_parent_directory "/tmp/aspis_repos"

  def run(_args) do
    with {:ok, _} <- Aspis.check_required_programs(),
         {:ok, deps} <- Utils.get_project_deps(),
         {:ok, hex_packages_from_mix_lock} <- Utils.get_packages_from_mix_lock(),
         {:ok, project_deps_path} <- Utils.get_project_deps_path() do
      deps_names = Enum.map(deps, &elem(&1, 0))

      relevant_packages =
        hex_packages_from_mix_lock
        |> Enum.filter(fn package -> package.name in deps_names end)

      git_urls =
        relevant_packages
        |> Enum.map(fn package ->
          {package.name, Utils.get_github_git_url(package.hex_name)}
        end)
        |> Map.new()

      # TODO make this more robust, it will mess up if we can't fetch the github url from the description
      git_urls =
        git_urls
        |> Enum.map(fn {k, {:ok, v}} -> {k, v} end)
        |> Map.new()

      Enum.each(relevant_packages, fn package ->
        repo_path = IO.inspect(Path.join(@git_parent_directory, Atom.to_string(package.name)))
        dep_path = IO.inspect(Path.join(project_deps_path, Atom.to_string(package.name)))
        git_url = git_urls[package.name]
        Aspis.prepare_repo(git_url, repo_path)

        case Aspis.checkout_version_by_tag(package.version, repo_path) do
          {:ok, _} ->
            IO.inspect(Aspis.get_relevant_file_diffs(repo_path, dep_path))
            IO.puts "#{package.name} PASSED!"
          _ ->
            IO.puts("COULD NOT CHECKOUT THE RIGHT VERSION")
        end
      end)
    else
      {:error, reason} when is_atom(reason) ->
        IO.puts "ERROR: #{reason}"
      {:error, reason} ->
        IO.puts "ERROR: #{inspect reason}"
    end
  end
end
