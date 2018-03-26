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
end
