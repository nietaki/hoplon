defmodule Aspis.HexPackage do
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

  def maybe_new(name, spec = {:hex, _hex_name, _version, _hash, [:mix], _deps, "hexpm"}) do
    [new(name, spec)]
  end

  def maybe_new(_, _) do
    []
  end
end
