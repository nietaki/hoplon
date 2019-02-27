defmodule Hoplon.Crypto do
  @doc """
  All the wrapper tools for low-level cryptography, specific to Hoplon's use-case.
  """

  # see https://crypto.stackexchange.com/a/10825 for why this is here
  @standard_rsa_public_exponent 65537
  @expected_key_bit_size 4096

  # if the message isn't digested, the signature fails for bigger messages (but not all that huge)
  @digest_type :sha512
  @rsa_pk_sign_verify_opts []

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

  @spec decode_private_key_from_pem(binary(), binary()) ::
          {:ok, Records.rsa_private_key()} | {:error, Error.t()}
  def decode_private_key_from_pem(pem_contents, password)
      when is_binary(pem_contents) and is_binary(password) do
    with {:ok, password} <- string_to_charlist(password),
         {:ok, only_entry} <- get_the_only_pem_entry(pem_contents),
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

  @spec decode_public_key_from_pem(binary()) ::
          {:ok, Records.rsa_public_key()} | {:error, Error.t()}
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

  @spec encode_public_key_to_pem(Records.rsa_public_key()) :: {:ok, binary()}
  def encode_public_key_to_pem(key) when is_public_key(key) do
    asn1_type = :SubjectPublicKeyInfo

    entry = :public_key.pem_entry_encode(asn1_type, key)
    pem_contents = :public_key.pem_encode([entry])
    {:ok, pem_contents}
  end

  @spec encode_private_key_to_pem(Records.rsa_private_key(), String.t()) :: {:ok, binary()}
  def encode_private_key_to_pem(key, password) when is_private_key(key) and is_binary(password) do
    with {:ok, password} <- string_to_charlist(password) do
      asn1_type = :RSAPrivateKey
      salt = :crypto.strong_rand_bytes(8)
      cipher_info = {'DES-EDE3-CBC', salt}

      entry = :public_key.pem_entry_encode(asn1_type, key, {cipher_info, password})
      pem_contents = :public_key.pem_encode([entry])
      {:ok, pem_contents}
    else
      {:error, %Error{}} = error ->
        error
    end
  end

  defp string_to_charlist(string) when is_binary(string) do
    codes = :unicode.characters_to_list(string, :utf8)
    all_printable_ascii? = Enum.all?(codes, &(&1 >= ?\s && &1 <= ?~))

    if all_printable_ascii? do
      {:ok, String.to_charlist(string)}
    else
      Error.new(:password_must_be_printable_ascii)
      |> Error.wrap()
    end
  end

  @spec get_signature(binary, Records.rsa_private_key()) :: binary()
  def get_signature(message, private_key)
      when is_binary(message) and is_private_key(private_key) do
    :public_key.sign(message, @digest_type, private_key, @rsa_pk_sign_verify_opts)
  end

  @spec verify_signature(binary, binary, Records.rsa_public_key()) :: boolean()
  def verify_signature(message, signature, public_key)
      when is_binary(message) and is_binary(signature) and is_public_key(public_key) do
    :public_key.verify(message, @digest_type, signature, public_key)
  end

  @spec hex_encode!(binary()) :: String.t()
  def hex_encode!(data) when is_binary(data) do
    Base.encode16(data, case: :lower)
  end

  @spec hex_decode(String.t()) :: {:ok, binary()} | {:error, Error.t()}
  def hex_decode(representation) when is_binary(representation) do
    case Base.decode16(representation, case: :mixed) do
      {:ok, _} = success ->
        success

      :error ->
        {:error, Error.new(:could_not_decode_hex)}
    end
  end

  @spec get_fingerprint(Records.rsa_public_key(), :md5 | :sha256 | :sha512) :: String.t()
  def get_fingerprint(public_key, digest_type \\ :sha256)
      when is_public_key(public_key) and digest_type in [:md5, :sha256, :sha512] do
    # NOTE: it seems like doing this directly through :public_key isn't possible/easy.
    #
    # This is a bit of a workaround to encode the public key to DER format
    # the same way openssl would (and in the analogous way :public_key does for PEM)
    # encoding.
    inner_der = :public_key.der_encode(:RSAPublicKey, public_key)

    # SEE https://github.com/erlang/otp/blob/3058ef6bb7a2a3f96cfde819976ee7a52be65364/lib/public_key/src/public_key.erl#L130
    der_null = <<5, 0>>

    # SEE https://github.com/erlang/otp/blob/709d0482af92ca52d26296f008b495a36161ca00/lib/public_key/asn1/PKCS-1.asn1#L22
    rsa_encryption_identifier = {1, 2, 840, 113_549, 1, 1, 1}

    # SEE https://github.com/erlang/otp/blob/3058ef6bb7a2a3f96cfde819976ee7a52be65364/lib/public_key/src/public_key.erl#L211-L215
    spki =
      {:SubjectPublicKeyInfo, {:AlgorithmIdentifier, rsa_encryption_identifier, der_null},
       inner_der}

    der = :public_key.der_encode(:SubjectPublicKeyInfo, spki)

    :crypto.hash(digest_type, der)
    |> Base.encode16(case: :lower)
  end
end
