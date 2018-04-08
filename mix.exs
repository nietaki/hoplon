defmodule Aspis.MixProject do
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
      app: :aspis,
      version: "0.1.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/nietaki/aspis",
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:excoveralls, "~> 0.4", only: :test}
      {:ex_doc, ">= 0.0.1", only: :dev, optional: true, runtime: false},
      # {:mix_test_watch, "~> 0.5", only: :dev, runtime: false}
    ]
  end
end
