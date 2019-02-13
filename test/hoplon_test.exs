defmodule HoplonTest do
  use ExUnit.Case
  doctest Hoplon

  use ExUnitProperties

  property "standard string concatenation stream data example" do
    check all bin1 <- binary(),
              bin2 <- binary() do
      assert String.starts_with?(bin1 <> bin2, bin1)
    end
  end
end
