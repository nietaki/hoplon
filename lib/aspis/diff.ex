defmodule Hoplon.Diff do

  alias Hoplon.Utils

  @moduledoc false

  @type file_difference ::
          {:only_in_left, relative_path :: String.t()}
          | {:only_in_right, relative_path :: String.t()}
          | {:files_differ, relative_path :: String.t()}

  def diff_files_in_directories(left, right) do
    # TODO the LC_ALL trick https://stackoverflow.com/a/11325364/246337
    {output, _status_code} = System.cmd("diff", ["-rq", left, right])

    output
    |> Utils.split_lines()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&extract_file_difference(&1, left, right))
  end

  def diff_dirs_raw(left, right, args \\ []) do
    args =
      case args do
        [] -> ["-r"]
        [_ | _] -> args
      end

    System.cmd("diff", args ++ [left, right])
  end

  # EXAMPLES:
  # "Only in /tmp/hoplon/ecto/integration_test: mysql"
  # "Files /foo/bar/something/deps/ecto/README.md and /tmp/hoplon/ecto/README.md differ"
  defp extract_file_difference(line, left, right) do
    only_in_left_prefix = "Only in " <> left
    only_in_right_prefix = "Only in " <> right
    files_differ_prefix = "Files " <> left

    only_in_left = String.starts_with?(line, only_in_left_prefix)
    only_in_right = String.starts_with?(line, only_in_right_prefix)
    differs = String.starts_with?(line, files_differ_prefix)

    case {only_in_left, only_in_right, differs} do
      {true, false, false} ->
        suffix = String.trim_leading(line, only_in_left_prefix)
        {:only_in_left, extract_relative_path_from_only_in(suffix)}

      {false, true, false} ->
        suffix = String.trim_leading(line, only_in_right_prefix)
        {:only_in_right, extract_relative_path_from_only_in(suffix)}

      {false, false, true} ->
        suffix = String.trim_leading(line, files_differ_prefix)
        {:files_differ, extract_relative_path_from_files_differ(suffix)}
    end
  end

  defp extract_relative_path_from_only_in(suffix) do
    [almost_relative, file] = String.split(suffix, ": ")
    relative = String.trim_leading(almost_relative, "/")
    Path.join([relative, file])
  end

  defp extract_relative_path_from_files_differ(suffix) do
    [relative, _rest] = String.split(suffix, " and ")
    relative
  end
end
