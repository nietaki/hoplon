defmodule Hoplon.CLI.Prompt do
  def for_string(prompt_text, opts \\ []) do
    response = IO.gets(io_device(opts), full_prompt(prompt_text))
    strip_ending_newline(response)
  end

  def for_password(prompt, opts \\ []) do
    if Keyword.get(opts, :clean_password, true) do
      password_clean(full_prompt(prompt))
    else
      for_string(prompt)
    end
  end

  def for_boolean(prompt, default \\ false) when is_boolean(default) do
    options_text =
      if default do
        "Y/n"
      else
        "y/N"
      end

    full_prompt = "#{prompt} (#{options_text})"
    string_response = for_string(full_prompt) |> String.downcase()

    case string_response do
      yes when yes in ["y", "yes"] ->
        true

      no when no in ["n", "no"] ->
        false

      "" ->
        default

      _other ->
        for_boolean(prompt, default)
    end
  end

  ## Helper functions

  defp full_prompt(prompt_text) do
    "\n> #{prompt_text}: "
  end

  defp io_device(opts) do
    Keyword.get(opts, :io_device, :stdio)
  end

  defp strip_ending_newline(user_input) do
    {actual_string, "\n"} = String.split_at(user_input, -1)
    actual_string
  end

  # SEE https://github.com/hexpm/hex/blob/ab402f98c1efe6855c93dfc5130c2b7a4b1ef753/lib/mix/tasks/hex.ex#L360-L392 for inspiration
  defp password_clean(prompt) do
    pid = spawn_link(fn -> loop(prompt) end)
    ref = make_ref()
    value = IO.gets(prompt)

    send(pid, {:done, self(), ref})
    receive do: ({:done, ^pid, ^ref} -> :ok)

    strip_ending_newline(value)
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send(parent, {:done, self(), ref})
        IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        prompt_without_newlines = String.replace(prompt, "\n", "")
        IO.write(:standard_error, "\e[2K\r#{prompt_without_newlines}")
        loop(prompt)
    end
  end
end
