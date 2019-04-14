defmodule Hoplon.CLI.Options do
  def default_switches() do
    [
      env: :string,
      hoplon_dir: :string
    ]
  end
end
