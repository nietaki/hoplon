defmodule Hoplon.DataTest do
  use ExUnit.Case
  use ExUnitProperties

  require Hoplon.Data
  alias Hoplon.Data
  alias Hoplon.Data.Encoder

  require Record
  import Record

  alias Support.Generators

  @moduletag :current

  describe ":Package" do
    test "package/0 creates a new empty record" do
      empty_package = Data.package()

      assert {:Package, :asn1_DEFAULT, :undefined, :undefined} == empty_package
      assert is_record(empty_package)
      assert is_record(empty_package, :Package)
      refute is_record(empty_package, :Audit)
    end

    test "encoding and decoding a fully defined record" do
      package = Data.package(ecosystem: "hex.pm", name: "foobar", version: "0.1.0")

      assert {:ok, encoded} = Encoder.encode(package)
      assert is_binary(encoded)

      assert {:ok, decoded} = Encoder.decode(encoded, :Package)
      assert decoded == package
    end

    property "record without default values can be encoded and decoded without any information loss" do
      check all package <- Generators.input_package(),
                !Generators.has_default_values?(package) do
        assert {:ok, encoded} = Encoder.encode(package)
        assert is_binary(encoded)

        assert {:ok, decoded} = Encoder.decode(encoded, :Package)
        assert decoded == package
      end
    end

    property "Package with a default ecosystem gets decoded as hex.pm" do
      check all base_package <- Generators.input_package() do
        package = Data.package(base_package, ecosystem: :asn1_DEFAULT)

        assert {:ok, encoded} = Encoder.encode(package)
        assert is_binary(encoded)

        assert {:ok, decoded} = Encoder.decode(encoded, :Package)
        assert decoded != package
        assert decoded == Data.package(package, ecosystem: "hex.pm")
      end
    end
  end

  describe ":Audit" do
    test "audit/0 create an empty record" do
      assert {:Audit, :undefined, :asn1_NOVALUE, :asn1_NOVALUE, :undefined, :undefined,
              :undefined} == Data.audit()

      refute is_record(Data.audit(), :Package)
    end

    test "encoding and decoding a fully defined record" do
      package = Data.package(ecosystem: "hex.pm", name: "foobar", version: "0.1.0")

      audit =
        Data.audit(
          package: package,
          verdict: :safe,
          message: "took me 10 hours",
          publicKeyFingerprint: "dummy",
          createdAt: 1_554_670_254,
          auditedByAuthor: false
        )

      assert {:ok, encoded} = Encoder.encode(audit)
      assert is_binary(encoded)

      assert {:ok, decoded} = Encoder.decode(encoded, :Audit)
      assert decoded == audit
    end

    property "encoding and decoding ALL audits" do
      check all audit <- Generators.input_audit() do
        assert {:ok, encoded} = Encoder.encode(audit)
        assert {:ok, decoded} = Encoder.decode(encoded, :Audit)

        assert decoded == Generators.fill_in_defaults(audit)
      end
    end
  end
end
