defmodule Hoplon.HexPackage do
  alias Hoplon.Utils

  @moduledoc false

  defstruct [
    :name,
    :hex_name,
    :version,
    :hash,
    depends_on: []
  ]

  def new(name, {:hex, hex_name, version, hash, _build_tools, deps, _hexpm}) do
    depends_on = Utils.get_deps_package_names(deps)

    %__MODULE__{
      name: name,
      hex_name: hex_name,
      version: version,
      hash: hash,
      depends_on: depends_on
    }
  end

  @spec has_name?(%__MODULE__{}, String.t() | atom) :: boolean
  def has_name?(package = %__MODULE__{}, name) do
    "#{name}" in ["#{package.name}", "#{package.hex_name}"]
  end

  # TODO relax the restrictions here on build tools
  def maybe_new(name, spec = {:hex, _hex_name, _version, _hash, [:mix], _deps, "hexpm"}) do
    [new(name, spec)]
  end

  def maybe_new(_, _) do
    []
  end
end
