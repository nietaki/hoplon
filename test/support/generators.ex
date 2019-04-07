defmodule Support.Generators do
  import ExUnitProperties
  import StreamData

  alias Hoplon.Data
  require Hoplon.Data

  def input_package() do
    gen all ecosystem <- frequency([{5, proper_string()}, {1, constant(:asn1_DEFAULT)}]),
            name <- proper_string(),
            version <- proper_string() do
      Data.package(ecosystem: ecosystem, name: name, version: version)
    end
  end

  def has_default_values?(record) when is_tuple(record) do
    record
    |> Tuple.to_list()
    |> Enum.any?(&(&1 == :asn1_DEFAULT))
  end

  def proper_string() do
    string(:printable)
  end
end
