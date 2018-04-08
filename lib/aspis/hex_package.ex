defmodule Aspis.HexPackage do

  @moduledoc false

  defstruct [
    :name,
    :hex_name,
    :version
  ]

  def new(name, {:hex, hex_name, version, _hash, _build_tools, _deps, _hexpm}) do
    %__MODULE__{
      name: name,
      hex_name: hex_name,
      version: version
    }
  end

  @spec has_name?(%__MODULE__{}, String.t() | atom) :: boolean
  def has_name?(package = %__MODULE__{}, name) do
    "#{name}" in ["#{package.name}", "#{package.hex_name}"]
  end

  def maybe_new(name, spec = {:hex, _hex_name, _version, _hash, [:mix], _deps, "hexpm"}) do
    [new(name, spec)]
  end

  def maybe_new(_, _) do
    []
  end
end
