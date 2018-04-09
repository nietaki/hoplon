defmodule Mix.Tasks.Aspis.ReleaseChecklist do
  use Mix.Task

  alias Aspis.Git
  alias Aspis.Utils

  @shortdoc "Prints a checklist for releasing aspis-compatible packages and its completion status"

  @moduledoc """
  """

  @doc "Runs the task"
  def run([]) do
    with {:ok, project_module} <- Utils.get_project(),
         project = project_module.project(),
         project_version = project[:version],
         {:ok, project_dir} <- Utils.get_project_root_directory(),
         {:ok, tags} <- Git.get_head_tags(project_dir) do
      IO.puts("project version: #{project_version}")
      IO.puts("git tags: #{inspect(tags)}")
      docs_source_url = project[:docs][:source_url]
      docs_source_url = docs_source_url || "MISSING"
      IO.puts("mix.exs docs/source_url: #{docs_source_url}")
      package_links = project[:package][:links]
      IO.puts("mix.exs package links: #{inspect(package_links)}")
    end
  end
end
