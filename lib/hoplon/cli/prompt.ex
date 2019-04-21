defmodule Hoplon.CLI.Prompt do
  def puts(item, opts) do
    IO.puts(io_device(opts), item)
  end

  def for_string(prompt_text, opts) do
    response = IO.gets(io_device(opts), full_prompt(prompt_text))
    strip_ending_newline(response)
  end

  def for_password(prompt, opts) do
    if Keyword.get(opts, :clean_password, true) do
      password_clean(full_prompt(prompt), opts)
    else
      for_string(prompt, opts)
    end
  end

  def for_boolean(prompt, default, opts) when is_boolean(default) do
    options_text =
      if default do
        "Y/n"
      else
        "y/N"
      end

    full_prompt = "#{prompt} (#{options_text})"
    string_response = for_string(full_prompt, opts) |> String.downcase()

    case string_response do
      yes when yes in ["y", "yes"] ->
        true

      no when no in ["n", "no"] ->
        false

      "" ->
        default

      _other ->
        for_boolean(prompt, default, opts)
    end
  end

  def print_table(headers, rows, opts) do
    column_count = Enum.count(headers)
    true = Enum.all?(rows, &(Enum.count(&1) == column_count))

    table =
      [headers | rows]
      |> map2(&convert_to_representation/1)

    column_lengths =
      table
      |> transpose()
      |> Enum.map(fn entries ->
        entries
        |> Enum.map(&String.length/1)
        |> Kernel.++([3])
        |> Enum.max()
      end)

    spacers = Enum.map(column_lengths, &String.duplicate("-", &1))
    [headers | rows] = table
    table = [headers, spacers | rows]

    rows =
      table
      |> Enum.map(fn row -> Enum.zip(row, column_lengths) end)
      |> map2(fn {text, min_length} -> String.pad_trailing(text, min_length) end)
      |> Enum.map(&Enum.join(&1, " | "))
      |> Enum.map(fn whole_row -> "| #{whole_row} |" end)

    Enum.each(rows, &puts(&1, opts))
  end

  defp transpose(rows) do
    rows
    |> Enum.to_list()
    |> List.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  defp map2(list_of_lists, function) do
    Enum.map(list_of_lists, fn list -> Enum.map(list, function) end)
  end

  defp convert_to_representation(nil) do
    "<nil>"
  end

  defp convert_to_representation(value) do
    String.Chars.to_string(value)
  end

  ## Helper functions

  defp full_prompt(prompt_text) do
    "\n> #{prompt_text}: "
  end

  defp io_device(opts) do
    Keyword.get(opts, :io_device, :stdio)
  end

  defp stderr_device(opts) do
    Keyword.get(opts, :stderr_device, :standard_error)
  end

  defp strip_ending_newline(user_input) do
    {actual_string, "\n"} = String.split_at(user_input, -1)
    actual_string
  end

  # SEE https://github.com/hexpm/hex/blob/ab402f98c1efe6855c93dfc5130c2b7a4b1ef753/lib/mix/tasks/hex.ex#L360-L392 for inspiration
  defp password_clean(prompt, opts) do
    io_device = io_device(opts)
    pid = spawn_link(fn -> loop(prompt, opts) end)
    ref = make_ref()
    value = IO.gets(io_device, prompt)

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)

    strip_ending_newline(value)
  end

  defp loop(prompt, opts) do
    stderr_device = stderr_device(opts)

    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(stderr_device, "\e[2K\r")
    after
      1 ->
        prompt_without_newlines = String.replace(prompt, "\n", "")
        IO.write(stderr_device, "\e[2K\r#{prompt_without_newlines}")
        loop(prompt, opts)
    end
  end
end
