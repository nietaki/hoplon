defmodule Hoplon.Lockfile do
  @enforce_keys [
    :absolved
  ]

  @default_values %{
    absolved: %{}
  }

  defstruct @enforce_keys

  def new(), do: new(%{})

  def new(nil), do: new(%{})

  def new(contents) when is_map(contents) do
    contents = Map.merge(@default_values, contents)
    struct(__MODULE__, contents)
  end

  def to_contents_map(lf = %__MODULE__{}) do
    Map.from_struct(lf)
  end

  def to_string(lf = %__MODULE__{}) do
    contents_map = to_contents_map(lf)

    Macro.to_string(quote(do: unquote(contents_map)))
    |> format_code()
  end

  defp format_code(code) do
    # only present in newer versions of Elixir, hoplon should work with older ones too
    if Keyword.has_key?(Code.__info__(:functions), :"format_string!") do
      code
      |> Code.format_string!(line_length: 98)
      |> IO.iodata_to_binary()
    else
      code
    end
  end

  def from_string(representation) do
    {result, _bindings} = Code.eval_string(representation)
    new(result)
  end

  def read!(path) do
    case File.read(path) do
      {:error, :enoent} -> new()
      {:ok, contents} -> from_string(contents)
    end
  end

  def write!(lf = %__MODULE__{}, path) do
    contents = __MODULE__.to_string(lf)
    File.write!(path, contents, [:write, :utf8])

    lf
  end

  def absolve(lf = %__MODULE__{absolved: absolved}, package, hash, message)
      when is_atom(package) and is_binary(hash) and is_binary(message) do
    package_map = Map.get(absolved, package, %{})
    absolved = Map.put(absolved, package, package_map)
    absolved = put_in(absolved, [package, hash], message)
    %__MODULE__{lf | absolved: absolved}
  end
end
