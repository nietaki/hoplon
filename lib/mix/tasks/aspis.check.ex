defmodule Mix.Tasks.Aspis.Check do
  use Mix.Task

  alias Aspis.Utils
  alias Aspis.CheckResult

  @shortdoc "check project's dependencies for hidden code"

  # TODO dehardcode this
  @git_parent_directory "/tmp/aspis_repos"

  def run(_args) do
    with {:ok, _} <- Aspis.check_required_programs(),
         {:ok, hex_packages_from_mix_lock} <- Utils.get_packages_from_mix_lock(),
         {:ok, project_deps_path} <- Utils.get_project_deps_path() do
      # TODO figure out if all of those are necessarily used or packages get kept in mix_lock after they stop being used
      relevant_packages = hex_packages_from_mix_lock

      IO.puts(CheckResult.header_line())

      results =
        Enum.map(relevant_packages, fn package ->
          Task.async(fn ->
            Aspis.check_package(package, @git_parent_directory)
          end)
        end)
        |> Stream.map(fn task ->
          Task.await(task)
        end)
        |> Stream.each(fn r ->
          r |> CheckResult.representation_line() |> IO.puts()
        end)
        |> Enum.to_list()

      combined_exit_code =
        results
        |> Enum.map(&CheckResult.get_status/1)
        |> Enum.map(&CheckResult.get_exit_code_from_status/1)
        |> Enum.reduce(&max/2)

      Utils.task_exit(combined_exit_code)
    else
      {:error, reason} when is_atom(reason) ->
        Utils.task_exit(1, inspect(reason))
    end
  end
end
