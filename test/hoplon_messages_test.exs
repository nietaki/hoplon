defmodule HoplonMessagesTest do
  use ExUnit.Case

  @tag :current
  test "can serialize and deserialize a person" do
    person = {:Person, "Jóźek", :home, :asn1_NOVALUE}
    assert {:ok, encoded} = :HoplonMessages.encode(:Person, person)
    # TODO take apart the person and assert the tag number (19) is in the encoded binary
    assert {:ok, person} == :HoplonMessages.decode(:Person, encoded)
  end
end
