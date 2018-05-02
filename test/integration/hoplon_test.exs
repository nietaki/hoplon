defmodule Integration.HoplonTest do
  use ExUnit.Case

  @moduletag :integration

  describe "check_required_programs()" do
    test "reports missing programs correctly" do
      made_up_programs = ["dkkldfoivnvlkd", "lqoiiodndkfldkfjsd"]

      assert {:error, {:missing_required_programs, made_up_programs}} ==
        Hoplon.check_required_programs(["sh"] ++ made_up_programs)
    end

    test "returns an :ok tuple for present programs" do
      assert {:ok, _} = Hoplon.check_required_programs(["sh", "pwd"])
    end
  end
end
