defmodule Hoplon.MixProject do
  use Mix.Project

  # RELEASE CHECKLIST
  # - bump version here
  # - update "Installation" section in the README with the new version
  # - check if README is outdated
  # - make sure there's no obviously missing or outdated docs
  # - push
  # - tag with the version and push the tag
  # - build and publish the hex package
  #   - mix hex.build
  #   - mix hex.publish

  def project do
    [
      app: :hoplon,
      version: "0.3.3",
      elixir: "~> 1.6",
      package: package(),
      start_permanent: false,
      deps: deps(),
      elixirc_options: [
        warnings_as_errors: true
      ],
      source_url: "https://github.com/nietaki/hoplon",
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:mix, :public_key, :crypto],
        ignore_warnings: "dialyzer_ignore.exs",
        list_unused_filters: true
      ],
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      {:dialyxir, "~> 1.0.0-rc4", only: [:dev, :test], optional: true, runtime: false},
      {:stream_data, "~> 0.4.2", only: :test},
      {:ex_doc, ">= 0.0.1", only: [:dev, :test], optional: true, runtime: false}
    ]
  end

  defp package() do
    [
      licenses: ["Apache 2.0"],
      maintainers: ["Jacek Królikowski <nietaki@gmail.com>"],
      links: %{
        "GitHub" => "https://github.com/nietaki/hoplon"
      },
      description: description(),
      # https://github.com/hexpm/hex/blob/master/lib/mix/tasks/hex.build.ex
      files: default_files() ++ ["scripts"],
      exclude_patterns: exclude_patterns()
    ]
  end

  defp default_files() do
    [
      "lib",
      # "priv",
      "mix.exs",
      "README*",
      # "readme*",
      "LICENSE*",
      # "license*",
      # "CHANGELOG*",
      # "changelog*",
      "src"
    ]
  end

  defp exclude_patterns() do
    [
      ~r{src/generated/.*\.(erl|hrl|asn1db|beam)}
    ]
  end

  defp description() do
    """
    Hoplon is a tool that verifies that your project's hex dependencies contain
    only the code they have listed on their GitHub.
    """
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/nietaki/hoplon",
      extras: ["README.md"],
      assets: ["assets"],
      logo: "assets/hoplon_logo_64.png"
    ]
  end

  defp aliases do
    [
      clean: ["clean", "run test/clean_tmp.exs"],
      # mix compile *does* get invoked by mix test
      compile: [&compile_asn1/1, "compile.erlang", "compile"]
    ]
  end

  defp compile_asn1(_args) do
    IO.puts("Compiling ASN.1 message encoder/decoder modules")
    # http://erlang.org/doc/apps/asn1/asn1_getting_started.html
    # http://erlang.org/doc/man/asn1ct.html#compile-1
    asn1_compilation_result =
      :asn1ct.compile(:HoplonMessages, [
        :ber,
        :der,
        :noobj,
        {:i, 'lib/'},
        {:outdir, 'src/generated/'}
      ])

    case asn1_compilation_result do
      :ok ->
        :ok

      {:error, _reason} ->
        exit({:shutdown, 1})
    end
  end
end
