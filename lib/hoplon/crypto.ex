defmodule Hoplon.Crypto do
  @doc """
  All the wrapper tools for low-level cryptography, specific to Hoplon's use-case.
  """

  # see https://crypto.stackexchange.com/a/10825 for why this is here
  @standard_rsa_public_exponent 65537
  @expected_key_bit_size 4096

  require Hoplon.Crypto.Records
  alias Hoplon.Crypto.Records

  @spec generate_private_key() :: Records.rsa_private_key()
  def generate_private_key() do
    :public_key.generate_key({:rsa, @expected_key_bit_size, @standard_rsa_public_exponent})
  end

  @spec build_public_key(Records.rsa_private_key()) :: Records.rsa_public_key()
  def build_public_key(private_key) do
    public_exponent = Records.rsa_private_key(private_key, :publicExponent)
    modulus = Records.rsa_private_key(private_key, :modulus)
    Records.rsa_public_key(publicExponent: public_exponent, modulus: modulus)
  end
end
