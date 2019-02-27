File.ls!("test/tmp/")
|> Enum.reject(&(&1 == ".gitignore"))
|> Enum.map(&("test/tmp/" <> &1))
|> Enum.each(&File.rm!/1)

IO.puts("Deleted files from test/tmp/")
