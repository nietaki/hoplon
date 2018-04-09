defmodule Mix.Tasks.Aspis.ReleaseChecklist do
  use Mix.Task

  alias Aspis.Git
  alias Aspis.Utils

  @shortdoc "Prints a checklist for releasing aspis-compatible packages and its completion status"

  @moduledoc """
  Prints a checklist for releasing aspis-compatible packages and its completion status
  """

  defmodule ChecklistItem do
    @moduledoc false

    defstruct [
      :checked?,
      :description,
      :instruction
    ]

    def new(checked?, description, instruction \\ nil) do
      %__MODULE__{
        checked?: checked?,
        description: description,
        instruction: instruction
      }
    end

    def represent(item = %__MODULE__{checked?: checked?}) do
      line = header(checked?) <> item.description

      if !checked? && !!item.instruction do
        line <> "\n      (#{item.instruction})"
      else
        line
      end
    end

    defp header(true), do: "- [x] "

    defp header(false), do: "- [ ] "
  end

  @doc "Runs the task"
  def run([]) do
    with {:ok, project_module} <- Utils.get_project(),
         project = project_module.project(),
         project_version = project[:version],
         {:ok, project_dir} <- Utils.get_project_root_directory(),
         {:ok, tags} <- Git.get_head_tags(project_dir) do
      source_url = project[:source_url]
      package_links = project[:package][:links]

      checklist = [
        ChecklistItem.new(
          source_url_valid?(source_url),
          "GitHub url in mix.exs project()[:source_url]"
        ),
        ChecklistItem.new(
          package_links_valid?(package_links),
          "GitHub url in Mix.exs project()[:package][:links]",
          "Add a `\"GitHub\" => \"https://github.com/<your_handle>/<project_name>\"` entry to the project()[:package][:links] colleciton in mix.exs"
        ),
        ChecklistItem.new(
          tags_valid?(tags, project_version),
          "Git commit tagged with the current project version",
          "run $ git tag v#{project_version} && git push origin v#{project_version}"
        )
      ]

      all_checked? =
        checklist
        |> Stream.each(fn item -> IO.puts(ChecklistItem.represent(item)) end)
        |> Enum.map(& &1.checked?)
        |> Enum.all?()

      exit_code =
        if all_checked? do
          0
        else
          1
        end

      Utils.task_exit(exit_code)
    else
      {:error, reason} ->
        Utils.task_exit(1, inspect(reason))
    end
  end

  @doc false
  def package_links_valid?(nil) do
    false
  end

  def package_links_valid?(links) do
    Enum.any?(links, &Utils.is_github_link?/1)
  end

  @doc false
  def source_url_valid?(nil) do
    false
  end

  def source_url_valid?(source_url) do
    Utils.is_github_link?({"github", source_url})
  end

  @doc false
  def tags_valid?(tags, version) do
    valid_version_tags = [version, "v" <> version]
    Enum.any?(tags, fn tag -> tag in valid_version_tags end)
  end
end
