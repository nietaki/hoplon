defmodule TestSupport.Tools do
  @temp_dir_base "/tmp/hoplon_tests"

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  def create_new_temp_directory() do
    subdirectory = random_string(10)
    path = Path.join(@temp_dir_base, subdirectory)
    File.mkdir_p!(path)
    path
  end
end
