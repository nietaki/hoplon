defmodule Hoplon.CLI.PromptTest do
  use ExUnit.Case
  alias Hoplon.CLI.Prompt

  import Support.Utils
  use ExUnit.Case

  @moduletag timeout: 10_000

  describe "print_table" do
    test "handles an example case" do
      opts = mock_input_opts("")
      headers = ["foo", :bingo, "bar baz"]

      rows = [
        [1, 2.0, "this is longer"],
        [true, false, nil]
      ]

      Prompt.print_table(headers, rows, opts)

      full_output = get_output_lines(opts) |> Enum.join("\n")

      assert full_output <> "\n" == """
             | foo  | bingo | bar baz        |
             | ---- | ----- | -------------- |
             | 1    | 2.0   | this is longer |
             | true | false | <nil>          |
             """
    end

    test "can do the right thing even with short columns" do
      opts = mock_input_opts("")
      headers = [1, 2]
      rows = [[1, 2]]
      Prompt.print_table(headers, rows, opts)

      full_output = get_output_lines(opts) |> Enum.join("\n")

      assert full_output <> "\n" == """
             | 1   | 2   |
             | --- | --- |
             | 1   | 2   |
             """
    end
  end
end
