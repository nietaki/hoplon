defmodule Hoplon.HexPackage do
  @moduledoc false

  defstruct [
    :name,
    :hex_name,
    :version,
    :hash
  ]

  def new(name, {:hex, hex_name, version, hash, _build_tools, _deps, _hexpm}) do
    %__MODULE__{
      name: name,
      hex_name: hex_name,
      version: version,
      hash: hash
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
