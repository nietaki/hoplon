# ![Hoplon](assets/hoplon_text_200.png)

Hoplon is a package that helps you verify that the code in your project's dependencies
contains exactly what's on their GitHub and no other malicious code.

**NOTE**: Hoplon is still in early stage of development and might not be stable enough for your needs.

[![travis badge](https://travis-ci.org/nietaki/hoplon.svg?branch=master)](https://travis-ci.org/nietaki/hoplon)
[![Hex.pm](https://img.shields.io/hexpm/v/hoplon.svg)](https://hex.pm/packages/hoplon)
[![docs](https://img.shields.io/badge/docs-hexdocs-yellow.svg)](https://hexdocs.pm/hoplon/)
[![Built with Spacemacs](https://cdn.rawgit.com/syl20bnr/spacemacs/442d025779da2f62fc86c2082703697714db6514/assets/spacemacs-badge.svg)](http://spacemacs.org)
<!--[![Coverage Status](https://coveralls.io/repos/github/nietaki/hoplon/badge.svg?branch=master)](https://coveralls.io/github/nietaki/hoplon?branch=master)-->

## Usage

To use Hoplon, add it as a dependency in your project.

Once it's in your deps, you can run `$ mix hoplon.check` to see if any of
the dependencies pulled into your project contain code that differs from
the code on their GitHub.

To see the diff for a specific package, run `$ mix hoplon.diff <package name>`.

Both of these mix tasks will exit with a non-zero code if any problems are
found - the dependencies differ from their github repository, the github
repository itself could not be found or the right commit could not be
identified by Hoplon.

## Installation

The package can be installed by adding `hoplon` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hoplon, ">= 0.1.0", app: false, runtime: false, optional: true}
  ]
end
```

In order for Hoplon to work correctly, you'll need `git` and `diff` programs in
your `PATH`.

## FAQ

### How do I know Hoplon is not malicious itself?

TODO (deps options and maybe other ways)

### How does it work?

TODO (conventions, heuristics, `git` and `diff`)
