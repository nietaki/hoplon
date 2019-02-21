defmodule Hoplon.Crypto do
  @doc """
  All the wrapper tools for low-level cryptography, specific to Hoplon's use-case.
  """

  # see https://crypto.stackexchange.com/a/10825 for why this is here
  @standard_rsa_public_exponent 65537
  @expected_key_bit_size 4096

  alias Hoplon.Error
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

  def decode_private_key_from_pem(pem_contents, password)
      when is_binary(pem_contents) and is_binary(password) do
    password = string_or_nil_to_charlist(password)

    with {:ok, only_entry} <- get_the_only_pem_entry(pem_contents),
         {:ok, ^only_entry} <- ensure_is_private_key_pem_entry(only_entry) do
      try do
        key = :public_key.pem_entry_decode(only_entry, password)
        {:ok, key}
      rescue
        e in MatchError ->
          {:error, _} = e.term

          Error.new(:could_not_decode_pem_with_given_password)
          |> Error.wrap()
      end
    else
      {:error, %Error{}} = error ->
        error
    end
  end

  defp ensure_is_private_key_pem_entry(pem_entry) when is_tuple(pem_entry) do
    case elem(pem_entry, 0) do
      :RSAPrivateKey -> {:ok, pem_entry}
      :SubjectPublicKeyInfo -> {:error, Error.new(:not_a_private_key)}
      _ -> {:error, Error.new(:invalid_private_key)}
    end
  end

  def decode_public_key_from_pem(pem_contents) when is_binary(pem_contents) do
    with {:ok, public_key_entry} <- get_the_only_pem_entry(pem_contents),
         {:ok, ^public_key_entry} <- ensure_is_public_key_pem_entry(public_key_entry) do
      key = :public_key.pem_entry_decode(public_key_entry)
      {:ok, key}
    else
      {:error, %Error{}} = error ->
        error
    end
  end

  defp ensure_is_public_key_pem_entry(pem_entry) when is_tuple(pem_entry) do
    case elem(pem_entry, 0) do
      :SubjectPublicKeyInfo ->
        {:ok, pem_entry}

      :RSAPrivateKey ->
        {:error, Error.new(:not_a_public_key)}

      _ ->
        {:error, Error.new(:invalid_public_key)}
    end
  end

  defp get_the_only_pem_entry(pem_contents) do
    case :public_key.pem_decode(pem_contents) do
      [only_entry] ->
        {:ok, only_entry}

      [] ->
        Error.new(:no_valid_pem_entries)
        |> Error.wrap()

      [_one, _two | _t] ->
        Error.new(:too_many_pem_entries)
        |> Error.wrap()
    end
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
