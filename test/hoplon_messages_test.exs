defmodule HoplonMessagesTest do
  use ExUnit.Case

  @tag :asn1
  test "can serialize and deserialize a person" do
    person = {:Person, "Jóźeks", :roving, :asn1_NOVALUE}
    assert {:ok, encoded} = :HoplonMessages.encode(:Person, person)
    File.write!("test/tmp/person_encoded.der", encoded)

    assert {_output, 0} =
             System.cmd("openssl", ~w{asn1parse -i -inform DER -in test/tmp/person_encoded.der})

    # IO.puts(output)

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

    # context-specific
    assert tag_class == 2
    # CONSTRUCTED
    assert pc == 1
    # as per the ASN1 file
    assert tag_number == 19
    assert byte_size(rest) == length

    assert <<
             # context specific
             2::size(2),
             # primitive,
             0::size(1),
             # 0, automatic tag for "name"
             0::size(5),
             # short length
             0::size(1),
             # length value
             length::size(7),
             "Jóźeks"::utf8,
             rest::binary
           >> = rest

    assert length == byte_size("Jóźeks")

    assert <<
             # context specific
             2::size(2),
             # primitive,
             0::size(1),
             # 1, automatic tag for "location"
             1::size(5),
             # short length
             0::size(1),
             # length
             1::size(7),
             # roving, value
             2
           >> == rest

    assert {:ok, person} == :HoplonMessages.decode(:Person, encoded)
  end
end
