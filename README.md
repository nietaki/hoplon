# ![Hoplon](assets/hoplon_text_200.png)

~~Hoplon is a package that helps you verify that the code in your project's dependencies
contains exactly what's on their GitHub and no other malicious code.~~

Hoplon is a set of tools to create and share signed "audits" describing the
security status of hexpm (or other) packages. It allows you to maintain
a collection of "trusted keys" - people whose audits you can fetch and take into
account when assessing packages you (want to) use.

See CodeBEAM STO [presentation slides](https://slides.com/nietaki/trust-issues/) for details.
Video of the talk coming soon.

[![travis badge](https://travis-ci.org/nietaki/hoplon.svg?branch=master)](https://travis-ci.org/nietaki/hoplon)
[![Hex.pm](https://img.shields.io/hexpm/v/hoplon.svg)](https://hex.pm/packages/hoplon)
[![docs](https://img.shields.io/badge/docs-hexdocs-yellow.svg)](https://hexdocs.pm/hoplon/)
<!--[![Coverage Status](https://coveralls.io/repos/github/nietaki/hoplon/badge.svg?branch=master)](https://coveralls.io/github/nietaki/hoplon?branch=master)-->

## Usage

There is no current version of hoplon on hex.pm, you need to get it from github:

    defp deps do
      [
        {:hoplon, github: "nietaki/hoplon"},
      ]
    end
     
After you add it to your dependencies, you gain access to the relevant hoplon tasks.
The currently relevant hoplon tasks are `mix hoplon.fetch`, `mix hoplon.my_key`,
`mix hoplon.status` and `mix hoplon.trusted_keys`

All of those mix tasks come with documentation:

    mix help hoplon.trusted_keys


