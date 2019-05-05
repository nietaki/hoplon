defmodule Hoplon.ApiClientTest do
  use ExUnit.Case
  alias Hoplon.ApiClient

  @moduletag :current
  describe "build_full_url" do
    test "works with duplicate keys" do
      base = "https://foo.bar/api"
      path = "some/path"
      query = [a: 1, a: 2]

      assert "https://foo.bar/api/some/path?a=1&a=2" ==
               ApiClient.build_full_url(base, path, query)
    end

    test "works without a query" do
      base = "https://foo.bar/api"
      path = "some/path"
      query = []

      assert "https://foo.bar/api/some/path" == ApiClient.build_full_url(base, path, query)
    end
  end
end
