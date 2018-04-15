defmodule Mix.Tasks.Hoplon.Absolve do
  use Mix.Task

  alias Hoplon.HexPackage
  alias Hoplon.Utils
  alias Hoplon.Lockfile

  @shortdoc "marks the package as OK, even if it differs from source or can't be resolved"

  @moduledoc """
  Marks the package as "absolved" - considered honest, even if its repository can't be found or
  its source differs from the package contents

      $ mix hoplon.absolve <package_name> <optional message>

  The package versions you absolve get stored in the `hoplon.lock` file next to the
  `mix.lock` file in the root of the project.
  """

  @doc "Runs the task"
  def run([package_name]) do
    run([package_name, "<no message>"])
  end

  def run([package_name, message]) do
    with {:ok, _} <- Hoplon.check_required_programs(),
         {:ok, hex_packages} <- Utils.get_packages_from_mix_lock(),
         {:ok, package} <- choose_hex_package(hex_packages, package_name),
         {:ok, hoplon_lock_path} <- Utils.get_hoplon_lock_path(),
         lockfile = Lockfile.read!(hoplon_lock_path) do
      # TODO absolve this
      lockfile
      |> Lockfile.absolve(package.hex_name, package.hash, message)
      |> Lockfile.write!(hoplon_lock_path)
    else
      {:error, reason} when is_atom(reason) ->
        Utils.task_exit(1, inspect(reason))
    end
  end

  def run(_) do
    Utils.task_exit(1, "USAGE: $ mix hoplon.absolve <package_name> <message>")
  end

  defp choose_hex_package(hex_packages, name) do
    case Enum.find(hex_packages, &HexPackage.has_name?(&1, name)) do
      nil ->
        {:error, :hex_package_not_found_in_dependencies}

      package ->
        {:ok, package}
    end
  end
end
