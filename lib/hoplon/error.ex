defmodule Hoplon.Error do
  @enforce_keys [:code]

  defstruct [
    :code,
    message: nil
  ]
end
