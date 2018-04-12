abort_bisect_code = -1

case System.argv() do
  [project_file, desired_version] ->
    # without it we can't load mix.exs
    Application.ensure_started(:mix)

    # NOTE this is an assumption, fix it
    [{module, _binary}] = Code.require_file(project_file)
    project_version = module.project()[:version]
    true = is_binary(project_version)

    # in git bisect run terms 0 is "old", 1 is "new"
    # in our case, the desired version or newer is "new"
    exit_code =
      case Version.compare(project_version, desired_version) do
        :gt -> 1
        :eq -> 1
        :lt -> 0
      end

    exit({:shutdown, exit_code})
  _ ->
    IO.puts("invalid arguments!")
    IO.puts("")
    IO.puts("Correct invocation:")
    IO.puts("$ elixir project_version_checker <path_to_mix_exs> <desired_version>")
    IO.puts("")
    exit({:shutdown, abort_bisect_code})
end

