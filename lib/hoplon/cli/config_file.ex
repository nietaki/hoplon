defmodule Hoplon.CLI.ConfigFile do
  @default_values %{
    trusted_keys: []
  }

  def new(), do: new(%{})

  def new(nil), do: new(%{})

  def new(config) when is_map(config) do
    Map.merge(@default_values, config)
  end

  def to_string(config) do
    Macro.to_string(quote(do: unquote(config)))
    |> format_code()
  end

  defp format_code(code) do
    # only present in newer versions of Elixir, hoplon should work with older ones too
    if Keyword.has_key?(Code.__info__(:functions), :format_string!) do
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

  def read_or_create!(path) do
    case File.read(path) do
      {:error, :enoent} ->
        config = new()
        write!(config, path)
        config

      {:ok, contents} ->
        from_string(contents)
    end
  end

  def write!(config, path) do
    contents = __MODULE__.to_string(config)
    File.write!(path, contents, [:write, :utf8])
  end
end
