defmodule Hoplon.Crypto do
  @doc """
  All the wrapper tools for low-level cryptography, specific to Hoplon's use-case.
  """

  # see https://crypto.stackexchange.com/a/10825 for why this is here
  @standard_rsa_public_exponent 65537
  @expected_key_bit_size 4096

  require Hoplon.Crypto.Records
  alias Hoplon.Crypto.Records

  defguard is_public_key(maybe_rsa_public_key)
           when is_tuple(maybe_rsa_public_key) and :RSAPublicKey == elem(maybe_rsa_public_key, 0)

  defguard is_private_key(maybe_rsa_private_key)
           when is_tuple(maybe_rsa_private_key) and
                  :RSAPrivateKey == elem(maybe_rsa_private_key, 0)

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

  def decode_key_from_pem(pem_contents, password \\ nil)
      when is_binary(pem_contents) and (is_nil(password) or is_binary(password)) do
    password = string_or_nil_to_charlist(password)
    entries = :public_key.pem_decode(pem_contents)
    [only_entry] = entries

    key =
      case password do
        nil ->
          :public_key.pem_entry_decode(only_entry)

        password ->
          :public_key.pem_entry_decode(only_entry, password)
      end

    {:ok, key}
  end

  def encode_key_to_pem(key, password \\ nil)
      when is_public_key(key) or
             (is_private_key(key) and (is_nil(password) or is_binary(password))) do
    password = string_or_nil_to_charlist(password)

    asn1_type =
      case elem(key, 0) do
        :RSAPrivateKey ->
          :RSAPrivateKey

        :RSAPublicKey ->
          :SubjectPublicKeyInfo
      end

    entry =
      case password do
        nil ->
          :public_key.pem_entry_encode(asn1_type, key)

        password ->
          salt = :crypto.strong_rand_bytes(8)
          cipher_info = {'DES-EDE3-CBC', salt}
          :public_key.pem_entry_encode(asn1_type, key, {cipher_info, password})
      end

    pem_contents = :public_key.pem_encode([entry])
    {:ok, pem_contents}
  end

  defp string_or_nil_to_charlist(nil) do
    nil
  end

  defp string_or_nil_to_charlist(string) when is_binary(string) do
    # TODO maybe assert the characters are ascii, to prevent compatibility issues?
    String.to_charlist(string)
  end
end
