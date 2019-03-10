defmodule HoplonMessagesTest do
  use ExUnit.Case

  test "can serialize and deserialize a person" do
    person = {:Person, "Jóźeks", :roving, :asn1_NOVALUE}
    assert {:ok, encoded} = :HoplonMessages.encode(:Person, person)
    File.write!("test/tmp/person_encoded.der", encoded)

    assert {_output, 0} =
             System.cmd("openssl", ~w{asn1parse -inform DER -in test/tmp/person_encoded.der})

    # IO.puts output

    # https://en.wikipedia.org/wiki/X.690#BER_encoding
    assert <<
             tag_class::size(2),
             pc::size(1),
             tag_number::size(5),
             # definite, short
             0::size(1),
             length::size(7),
             rest::binary
           >> = encoded

    # APPLICATION
    assert tag_class == 1
    # CONSTRUCTED
    assert pc == 1
    # as per the ASN1 file
    assert tag_number == 19
    assert byte_size(rest) == length

    assert <<
             # universal
             0::size(2),
             # primitive,
             0::size(1),
             # UTFF8String
             12::size(5),
             # short length
             0::size(1),
             # string length
             length::size(7),
             "Jóźeks"::utf8,
             rest::binary
           >> = rest

    assert length == byte_size("Jóźeks")

    assert <<
             # simplified, integer,
             2,
             # length
             1,
             # roving, value
             2
           >> == rest

    assert {:ok, person} == :HoplonMessages.decode(:Person, encoded)
  end
end
