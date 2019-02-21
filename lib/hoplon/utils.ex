defmodule Hoplon.Utils do
  @moduledoc false

  def github_regex(), do: ~r|^https://github.com/[\w_.-]+/[\w_.-]+|

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

  def get_deps_package_names(deps_list) do
    deps_list
    |> Enum.map(&normalize_package_entry/1)
    |> Enum.filter(&is_hex_entry/1)
    |> Enum.map(&inject_hex_name/1)
    |> Enum.map(&elem(&1, 0))
  end

  defp is_hex_entry({_p, _, opts}) do
    opts_keys = Keyword.keys(opts)
    non_hex_keys = [:git, :github, :path]

    opts_keys -- non_hex_keys == opts_keys
  end

  defp inject_hex_name({p, req, opts}) do
    case Keyword.get(opts, :hex) do
      nil ->
        {p, req, opts}

      hex_name when is_atom(hex_name) ->
        {hex_name, req, opts}
    end
  end

  defp normalize_package_entry({package, req}) when is_binary(req) do
    {package, req, []}
  end

  defp normalize_package_entry({package, opts}) when is_list(opts) do
    {package, "", opts}
  end

  defp normalize_package_entry(entry = {_, _, _}) do
    entry
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
        {:ok, String.replace_suffix(mix_exs_path, "mix.exs", "mix.lock")}

      [_ | _] ->
        {:error, :too_many_mix_exs_files_found}
    end
  end

  def get_hoplon_lock_path() do
    case get_mix_lock_path() do
      {:ok, mix_exs_path} ->
        # yes, doing the work twice
        {:ok, String.replace_suffix(mix_exs_path, "mix.lock", "hoplon.lock")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_project_root_directory() do
    with {:ok, mix_lock_path} <- get_mix_lock_path() do
      {:ok, Path.dirname(mix_lock_path)}
    end
  end

  def get_packages_from_mix_lock() do
    with {:ok, mix_lock_path} <- get_mix_lock_path() do
      case File.regular?(mix_lock_path) do
        false ->
          []

        true ->
          res =
            mix_lock_path
            |> eval_lockfile()
            |> Enum.flat_map(fn {name, spec} -> Hoplon.HexPackage.maybe_new(name, spec) end)

          {:ok, res}
      end
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

    matching_urls =
      links
      |> Enum.filter(&is_github_link?/1)
      |> Enum.map(fn {_, url} -> url end)
      |> Enum.map(&Regex.run(github_regex(), &1))
      |> Enum.map(fn [match] -> match <> ".git" end)

    case matching_urls do
      [] -> {:error, :no_github_url_found}
      [url] -> {:ok, url}
      [_ | _] -> {:error, :multiple_github_urls_found}
    end
  end

  def is_github_link?({name, url}) do
    name_relevant = String.downcase(name) == "github"

    url_relevant = Regex.match?(github_regex(), url)
    name_relevant && url_relevant
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

  def split_lines(string) do
    String.split(string, ~r/\R/, trim: true)
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

  defp eval_lockfile(lockfile) do
    opts = [file: lockfile, warn_on_unnecessary_quotes: false]

    with {:ok, contents} = File.read(lockfile),
         {:ok, quoted} = Code.string_to_quoted(contents, opts),
         {%{} = lock, _binding} = Code.eval_quoted(quoted, opts) do
      lock
    end
  end
end
