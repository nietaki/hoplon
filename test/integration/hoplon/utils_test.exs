defmodule Integration.Hoplon.UtilsTest do
  alias Hoplon.Utils

  use ExUnit.Case
  @moduletag :integration

  test "get_project()" do
    assert {:ok, module} = Utils.get_project()
    assert Hoplon.MixProject == module
  end

  test "get_project_deps()" do
    assert {:ok,
      [
        {:ex_doc, ">= 0.0.1", only: :dev, optional: true, runtime: false},
        {:excoveralls, "~> 0.8.1", only: :test, optional: true},
      ]
    } == Utils.get_project_deps()
  end
end
