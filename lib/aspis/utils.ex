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
    with {:ok, module} <- get_project()
    do
      module.project() |> Keyword.fetch(:deps)
    end
  end


  def get_project_deps_path() do
    {:ok, Mix.Project.deps_path()}
  end
end
