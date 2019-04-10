defmodule Hoplon.DataTest do
  use ExUnit.Case
  use ExUnitProperties

  require Hoplon.Data
  alias Hoplon.Data
  alias Hoplon.Data.Encoder

  require Record
  import Record

  alias Support.Generators

  describe ":Package" do
    test "package/0 creates a new empty record" do
      empty_package = Data.package()

      assert {:Package, :asn1_DEFAULT, :undefined, :undefined, :undefined} == empty_package
      assert is_record(empty_package)
      assert is_record(empty_package, :Package)
      refute is_record(empty_package, :Audit)
    end

    test "proper error when encoding and decoding a record missing a field" do
      package = Data.package(ecosystem: "hexpm", version: "0.1.0", hash: "deadbeef")

      assert {:error, _} = Encoder.encode(package)
    end

    test "encoding and decoding a fully defined record" do
      package =
        Data.package(ecosystem: "hexpm", name: "foobar", version: "0.1.0", hash: "deadbeef")

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

    property "Package with a default ecosystem gets decoded as hexpm" do
      check all base_package <- Generators.input_package() do
        package = Data.package(base_package, ecosystem: :asn1_DEFAULT)

        assert {:ok, encoded} = Encoder.encode(package)
        assert is_binary(encoded)

        assert {:ok, decoded} = Encoder.decode(encoded, :Package)
        assert decoded != package
        assert decoded == Data.package(package, ecosystem: "hexpm")
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
      package =
        Data.package(ecosystem: "hexpm", name: "foobar", version: "0.1.0", hash: "deadbeef")

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

    property "(partially) garbage audits can't be decoded" do
      check all audit <- Generators.input_audit(),
                {:ok, encoded} = Encoder.encode(audit),
                message_length = byte_size(encoded),
                kept_size <- integer(0..div(message_length, 2)),
                garbage <- binary(min_length: 0, max_length: message_length) do
        kept_part = binary_part(encoded, 0, kept_size)
        malformed_message = kept_part <> garbage
        assert {:error, {:asn1, _}} = Encoder.decode(malformed_message, :Audit)
      end
    end

    property "an encoded Audit can't be decoded as a different struct" do
      check all audit <- Generators.input_audit(),
                {:ok, encoded} = Encoder.encode(audit),
                other_tag <- one_of([:Package, :SignedAudit]) do
        assert {:error, {:asn1, _}} = Encoder.decode(encoded, other_tag)
      end
    end
  end

  describe ":SignedAudit" do
    property "encoding and decoding signed audits" do
      check all signed_audit <- Generators.input_signed_audit() do
        assert {:ok, encoded} = Encoder.encode(signed_audit)
        assert {:ok, decoded} = Encoder.decode(encoded, :SignedAudit)

        assert decoded == Generators.fill_in_defaults(signed_audit)
      end
    end
  end
end
