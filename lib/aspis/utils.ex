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

  def get_packages_from_mix_lock(mix_lock_path \\ get_mix_lock_path()) do
    case File.regular?(mix_lock_path) do
      false ->
        []

      true ->
        {map, _} = Code.eval_file(mix_lock_path)

        res =
          map
          |> Enum.flat_map(fn {name, spec} -> Aspis.HexPackage.maybe_new(name, spec) end)

        {:ok, res}
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

  def cmd(command, args, cd_path \\ nil, opts \\ []) when is_binary(command) and is_list(args) do
    cmd_opts =
      case cd_path do
        nil -> []
        cd_path -> [cd: cd_path]
      end

    System.cmd(command, args, opts ++ cmd_opts)
    |> cast_cmd_result()
  end

  def program_exists?(program_name) when is_binary(program_name) do
    case cmd("which", [program_name]) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def task_exit(exit_code, message \\ nil) when is_integer(exit_code) do
    case {exit_code, message} do
      {_, nil} -> :ok
      {_, ""} -> :ok
      {0, msg} when is_binary(msg) -> IO.puts("OK: " <> msg)
      {_, msg} when is_binary(msg) -> IO.puts("ERROR: " <> msg)
    end

    exit({:shutdown, exit_code})
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
