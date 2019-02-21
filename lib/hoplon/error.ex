defmodule Hoplon.Error do
  @enforce_keys [:code]

  defstruct [
    :code,
    message: nil
  ]

  def new(code, message \\ nil) when is_atom(code) and (is_nil(message) or is_binary(message)) do
    %__MODULE__{
      code: code,
      message: message
    }
  end

  def wrap(error = %__MODULE__{}) do
    {:error, error}
  end

  # def wrap(success) do
  #   {:ok, success}
  # end
end
