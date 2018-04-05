[![travis badge](https://travis-ci.org/nietaki/aspis.svg?branch=master)](https://travis-ci.org/nietaki/aspis)
[![Hex.pm](https://img.shields.io/hexpm/v/aspis.svg)](https://hex.pm/packages/aspis) 
[![docs](https://img.shields.io/badge/docs-hexdocs-yellow.svg)](https://hexdocs.pm/aspis/) 
[![Built with Spacemacs](https://cdn.rawgit.com/syl20bnr/spacemacs/442d025779da2f62fc86c2082703697714db6514/assets/spacemacs-badge.svg)](http://spacemacs.org)
<!--[![Coverage Status](https://coveralls.io/repos/github/nietaki/aspis/badge.svg?branch=master)](https://coveralls.io/github/nietaki/aspis?branch=master)-->

# Aspis

Aspis is a package that helps you verify that the code in your project's dependencies
contains exactly what's on their GitHub and no other malicious code.

**NOTE**: Aspis is still in early stage of development and might be missing some features.

## Usage

To use Aspis, add it as a dependency in your project.

Once it's in your deps, you can run `$ mix aspis.check` to see if any of
the dependencies pulled into your project contain code that differs from 
the code on their GitHub.

To see the diff for a specific package, run `$ mix aspis.diff <package name>`.

Both of these mix tasks will exit with a non-zero code if any problems are
found - the dependencies differ from their github repository, the github
repository itself could not be found or the right commit could not be
identified by Aspis.

## Installation

The package can be installed by adding `aspis` to your list of 
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aspis, ">= 0.1.0", app: false, runtime: false, optional: true}
  ]
end
```

In order for Aspis to work correctly, you'll need `git` and `diff` programs in
your `PATH`. 

## FAQ

### How do I know Aspis is not malicious itself?

TODO (deps options and maybe other ways)

### How does it work?

TODO (conventions, heuristics, `git` and `diff`)
