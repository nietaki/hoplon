defmodule Hoplon.DataTest do
  use ExUnit.Case

  require Hoplon.Data
  alias Hoplon.Data

  require Record
  import Record

  @moduletag :current

  describe ":Package" do
    test "package/0 creates a new empty record" do
      empty_package = Data.package()

      assert {:Package, :asn1_DEFAULT, :undefined, :undefined} == empty_package
      assert is_record(empty_package)
      assert is_record(empty_package, :Package)
    end

    test "encoding and decoding a fully defined record" do
      package = Data.package(ecosystem: "hex.pm", name: "foobar", version: "0.1.0")

      assert {:ok, encoded} = Data.encode(package)
      assert is_binary(encoded)

      assert {:ok, decoded} = Data.decode(encoded, :Package)

      assert decoded == package
    end
  end
end
