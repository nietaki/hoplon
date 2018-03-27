defmodule Aspis.Utils do
  def get_project() do
    case Mix.Project.get() do
      nil ->
        {:error, :project_not_found}

      module ->
        {:ok, module}
    end
  end

  def get_project_deps() do
    with {:ok, module} <- get_project() do
      module.project() |> Keyword.fetch(:deps)
    end
  end

  def get_project_deps_path() do
    {:ok, Mix.Project.deps_path()}
  end

  def get_mix_lock_path() do
    mix_exs_files =
      Mix.Project.config_files()
      |> Enum.filter(&String.ends_with?(&1, "/mix.exs"))

    case mix_exs_files do
      [] ->
        {:error, :mix_exs_not_found}

      [mix_exs_path] ->
        String.replace_suffix(mix_exs_path, "mix.exs", "mix.lock")

      [_ | _] ->
        {:error, :too_many_mix_exs_files_found}
    end
  end

  def get_relevant_packages_from_mix_lock(mix_lock_path \\ get_mix_lock_path()) do
    case File.regular?(mix_lock_path) do
      false ->
        []

      true ->
        {map, _} = Code.eval_file(mix_lock_path)

        map
        |> Enum.flat_map(fn {name, spec} -> Aspis.HexPackage.maybe_new(name, spec) end)
    end
  end

  def get_hex_info(package) when is_atom(package) do
    get_hex_info(Atom.to_string(package))
  end

  def get_hex_info(package) when is_binary(package) do
    # TODO dehardcode "hexpm"
    # TODO error handling
    {:ok, {200, data, _headers}} = Hex.API.Package.get("hexpm", package)
    {:ok, data}
  end

  def get_github_git_url(package) do
    {:ok, data} = get_hex_info(package)
    links = get_in(data, ["meta", "links"])

    github_regex = ~r|^https://github.com/[\w_-]+/[\w_-]+|

    matching_urls =
      links
      |> Enum.filter(fn {name, url} ->
        name_relevant = String.downcase(name) == "github"

        url_relevant = Regex.match?(github_regex, url)
        name_relevant && url_relevant
      end)
      |> Enum.map(fn {_, url} -> url end)
      |> Enum.map(&Regex.run(github_regex, &1))
      |> Enum.map(fn [match] -> match <> ".git" end)

    case matching_urls do
      [] -> {:error, :no_github_url_found}
      [url] -> {:ok, url}
      [_ | _] -> {:error, :multiple_github_urls_found}
    end
  end
end
