defmodule Hoplon.MixProject do
  use Mix.Project

  # RELEASE CHECKLIST
  # - update the version here
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
      version: "0.2.1",
      elixir: "~> 1.4",
      package: package(),
      start_permanent: false,
      deps: deps(),
      source_url: "https://github.com/nietaki/hoplon"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.1", only: :dev, optional: true, runtime: false}
    ]
  end

  defp package() do
    [
      licenses: ["MIT"],
      maintainers: ["Jacek Królikowski <nietaki@gmail.com>"],
      links: %{
        "GitHub" => "https://github.com/nietaki/hoplon"
      },
      description: description(),
      files: default_files() ++ ["scripts"]
    ]
  end

  defp default_files() do
    [
      "lib",
      # "priv",
      "mix.exs",
      "README*",
      # "readme*",
      "LICENSE*"
      # "license*",
      # "CHANGELOG*",
      # "changelog*",
      # "src"
    ]
  end

  defp description do
    """
    Hoplon is a tool that verifies that your project's hex dependencies contain
    only the code they have listed on their GitHub.
    """
  end
end
