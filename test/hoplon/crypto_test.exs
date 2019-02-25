defmodule Hoplon.CryptoTest do
  alias Hoplon.Error
  use ExUnit.Case
  use ExUnitProperties

  doctest Hoplon.Crypto
  doctest Hoplon.Crypto.Records

  require Hoplon.Crypto.Records
  require Record

  alias Hoplon.Crypto.Records
  alias Hoplon.Crypto
  require Hoplon.Crypto

  @password "test"
  @password_charlist 'test'
  # https://crypto.stackexchange.com/a/10825
  @standard_rsa_public_exponent 65537

  @long_property_test_time_limit_ms 300

  test "generate_private_key and generated private key accessors" do
    private_key = Crypto.generate_private_key()

    assert is_tuple(private_key)
    assert elem(private_key, 0) == :RSAPrivateKey
    assert Records.rsa_private_key(private_key, :publicExponent) == @standard_rsa_public_exponent
    modulus = Records.rsa_private_key(private_key, :modulus)

    expected_key_bit_size = 4096
    assert Math.pow(2, expected_key_bit_size - 1) <= modulus
    assert Math.pow(2, expected_key_bit_size) > modulus
  end

  test "decoding and encoding a public key pem file" do
    public_key_pem_file_contents = File.read!("test/assets/public.pem")
    assert {:ok, public_key} = Crypto.decode_public_key_from_pem(public_key_pem_file_contents)
    assert Crypto.is_public_key(public_key)

    # assert {:ok, public_key} = Crypto.decode_private_key_from_pem(public_key_pem_file_contents, "test")
    # flunk("")

    assert {:ok, pem_contents} = Crypto.encode_key_to_pem(public_key)
    assert_same_pem(public_key_pem_file_contents, pem_contents)
  end

  # pems can differ by a newline character at the end
  defp assert_same_pem(pem1, pem2) do
    pem_length = min(String.length(pem1), String.length(pem2))
    {main1, rest1} = String.split_at(pem1, pem_length)
    {main2, rest2} = String.split_at(pem2, pem_length)

    assert main1 == main2
    assert rest1 in ["", "\n"]
    assert rest2 in ["", "\n"]
  end

  test "decoding and encoding a private key pem file with a password" do
    private_key_pem_file_contents = File.read!("test/assets/private.pem")

    assert {:ok, private_key} =
             Crypto.decode_private_key_from_pem(private_key_pem_file_contents, @password)

    assert Crypto.is_private_key(private_key)

    assert {:ok, pem_contents} = Crypto.encode_key_to_pem(private_key, @password)

    # they will be differente because of a different salt in the pem entry
    refute private_key_pem_file_contents == pem_contents

    # but when decoded again the keys will be the same
    assert {:ok, private_key} == Crypto.decode_private_key_from_pem(pem_contents, @password)
  end

  test "trying to decode a private key as if it was a public key errors out" do
    pem = File.read!("test/assets/private.pem")
    assert {:error, %Error{code: code}} = Crypto.decode_public_key_from_pem(pem)
    assert code == :not_a_public_key
  end

  property "trying to decode a garbage pem errors out neatly" do
    check all malformed_pem <- string(:ascii),
              password <- string(:alphanumeric) do
      assert {:error, %Error{code: code}} = Crypto.decode_public_key_from_pem(malformed_pem)
      assert code in [:no_valid_pem_entries]

      assert {:error, %Error{code: code}} =
               Crypto.decode_private_key_from_pem(malformed_pem, password)

      assert code in [:no_valid_pem_entries]
    end
  end

  property "trying to decode a pem with an invalid password password errors out neatly" do
    pem = File.read!("test/assets/private.pem")

    check all password <- string(:alphanumeric),
              password != @password do
      assert {:error, %Error{code: code}} = Crypto.decode_private_key_from_pem(pem, password)
      assert code == :could_not_decode_pem_with_given_password
    end
  end

  property "trying to decode a public key as if it was a private key, with a random password errors out neatly" do
    pem = File.read!("test/assets/public.pem")

    check all password <- string(:alphanumeric),
              password != "" do
      assert {:error, %Error{code: code}} = Crypto.decode_private_key_from_pem(pem, password)
      assert code == :not_a_private_key
    end
  end

  property "signing a binary message can be verified using the public key" do
    check all private_key <- private_key_gen(),
              message <- message_gen(),
              max_run_time: @long_property_test_time_limit_ms do
      public_key = Crypto.build_public_key(private_key)
      signature = Crypto.get_signature(message, private_key)
      assert byte_size(signature) == 512
      assert Crypto.verify_signature(message, signature, public_key)
    end
  end

  property "a signature won't be verified if you're using the wrong key" do
    check all private_key <- private_key_gen(),
              another_private_key <- private_key_gen(),
              message <- message_gen(),
              max_run_time: @long_property_test_time_limit_ms do
      another_public_key = Crypto.build_public_key(another_private_key)
      signature = Crypto.get_signature(message, private_key)
      refute Crypto.verify_signature(message, signature, another_public_key)
    end
  end

  property "any binary can be hex encoded and decoded" do
    check all data <- binary() do
      hex = Crypto.hex_encode!(data)
      assert {:ok, data} == Crypto.hex_decode(hex)
      assert byte_size(hex) == byte_size(data) * 2
    end
  end

  property "decoding of hex allows for both lower and upercase encoding" do
    check all data <- binary() do
      hex = Crypto.hex_encode!(data)
      assert {:ok, data} == Crypto.hex_decode(String.downcase(hex))
      assert {:ok, data} == Crypto.hex_decode(String.upcase(hex))
    end
  end

  test "trying to decode an invalid hex string returns a good error" do
    assert {:error, %Error{code: :could_not_decode_hex}} = Crypto.hex_decode("foobar")
  end

  test "hex signature aligns with the one obtained through openssl" do
    # NOTE: message.sig.hex was obtained as follows:
    # $ openssl pkeyutl -sign -in message.digest -inkey private.pem -hexdump -out message.sig.hex -pkeyopt digest:sha512

    private_key_pem_file_contents = File.read!("test/assets/private.pem")

    assert {:ok, private_key} =
             Crypto.decode_private_key_from_pem(private_key_pem_file_contents, @password)

    message = File.read!("test/assets/message.txt")

    hoplon_signature_hex =
      Crypto.get_signature(message, private_key)
      |> Crypto.hex_encode!()

    # The file is in the following format:
    #
    # 0000 - 7b 14 14 4e d2 c0 e5 84-91 ae 9a 35 66 e5 f7 90   {..N.......5f...
    # 0010 - 01 d3 76 fb a6 e6 5e 0a-90 94 9a 60 c7 7b 0e 2d   ..v...^....`.{.-
    # 0020 - 36 dd 16 05 e1 95 65 61-58 a8 94 b9 75 13 6b c8   6.....eaX...u.k.
    openssh_signature_hex =
      File.read!("test/assets/message.sig.hex")
      |> String.split("\n")
      |> Enum.map(fn line ->
        line
        |> String.slice(7..54)
        |> String.replace([" ", "-"], "")
      end)
      |> Enum.join("")

    assert hoplon_signature_hex == openssh_signature_hex
  end

  test "getting public key fingerprint" do
    # $ openssl rsa -in public.pem -pubin -pubout -outform DER | openssl md5 -c
    # writing RSA key
    # 33:3d:09:0e:e1:82:4f:61:6e:a2:11:79:a3:f1:46:c7
    #
    # $ openssl rsa -in public.pem -pubin -pubout -outform DER | openssl md5
    # writing RSA key
    # 333d090ee1824f616ea21179a3f146c7
    #
    # $ openssl rsa -in public.pem -pubin -pubout -outform DER | openssl sha256
    # writing RSA key
    # e002c6fe18f1f3645f96cd9a73b7163ea0cd799d170f72d15679422b71d35606
    # $ openssl rsa -in public.pem -pubin -pubout -outform DER | openssl sha512
    # writing RSA key
    # df4724b5a64b86282861ad4cd3d32eb798542fe37149de33b54168230dbc8f03e04cbf45da8a58db39ff278419a9f72fb7edfd889738b8dd1464fe611e189883

    md5_hash = "333d090ee1824f616ea21179a3f146c7"
    sha256_hash = "e002c6fe18f1f3645f96cd9a73b7163ea0cd799d170f72d15679422b71d35606"

    sha512_hash =
      "df4724b5a64b86282861ad4cd3d32eb798542fe37149de33b54168230dbc8f03e04cbf45da8a58db39ff278419a9f72fb7edfd889738b8dd1464fe611e189883"

    public_key_pem = File.read!("test/assets/public.pem")
    assert {:ok, public_key} = Crypto.decode_public_key_from_pem(public_key_pem)

    assert md5_hash == Crypto.get_fingerprint(public_key, :md5)
    assert sha256_hash == Crypto.get_fingerprint(public_key, :sha256)
    assert sha512_hash == Crypto.get_fingerprint(public_key, :sha512)
  end

  ### StreamData generators

  def private_key_gen() do
    StreamData.binary()
    |> StreamData.map(fn _ ->
      Crypto.generate_private_key()
    end)
    |> StreamData.unshrinkable()
  end

  def message_gen() do
    StreamData.binary(min_length: 13)
  end

  describe "using `public_key` utilities directly" do
    test "interacting with pem keys generated using openssl" do
      # the keys were generated using the following commands:
      # $ openssl genrsa -des3 -out private.pem 4096
      # using "test" as the password
      # $ openssl rsa -in private.pem -outform PEM -pubout -out public.pem

      private_key_pem_file_contents = File.read!("test/assets/private.pem")
      entries = :public_key.pem_decode(private_key_pem_file_contents)
      assert [rsa_private_key_entry] = entries

      assert {:RSAPrivateKey, encrypted_der, cipher_info} = rsa_private_key_entry
      assert is_binary(encrypted_der)
      assert {'DES-EDE3-CBC', salt} = cipher_info
      assert is_binary(salt)
      assert byte_size(salt) == 8

      rsa_private_key = :public_key.pem_entry_decode(rsa_private_key_entry, @password_charlist)
      assert is_tuple(rsa_private_key)
      assert :RSAPrivateKey = elem(rsa_private_key, 0)

      assert is_integer(Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :modulus))

      # public key
      public_key_pem_file_contents = File.read!("test/assets/public.pem")
      entries = :public_key.pem_decode(public_key_pem_file_contents)
      assert [rsa_public_key_entry] = entries

      assert {:SubjectPublicKeyInfo, _der, :not_encrypted} = rsa_public_key_entry
      assert is_binary(salt)
      assert byte_size(salt) == 8

      rsa_public_key = :public_key.pem_entry_decode(rsa_public_key_entry)
      assert is_tuple(rsa_public_key)
      assert :RSAPublicKey = elem(rsa_public_key, 0)

      assert is_integer(Hoplon.Crypto.Records.rsa_public_key(rsa_public_key, :modulus))

      public_exponent = Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :publicExponent)
      assert public_exponent == @standard_rsa_public_exponent
      modulus = Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :modulus)

      assert rsa_public_key ==
               Hoplon.Crypto.Records.rsa_public_key(
                 publicExponent: public_exponent,
                 modulus: modulus
               )
    end

    test "generating new RSA key pair" do
      size = 2048
      rsa_private_key = :public_key.generate_key({:rsa, size, @standard_rsa_public_exponent})
      assert Record.is_record(rsa_private_key)
      modulus = Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :modulus)

      # logarithms on big numbers are hard for erlang
      assert Math.pow(2, size - 1) <= modulus
      assert Math.pow(2, size) > modulus
    end

    test "signing and verifying a signature" do
      size = 2048
      rsa_private_key = :public_key.generate_key({:rsa, size, @standard_rsa_public_exponent})
      public_exponent = Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :publicExponent)
      modulus = Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :modulus)

      message = "I'm an arbitrary binary message that happens to be an ascii string! "
      message = String.duplicate(message, 100)

      # if the message isn't digested, the signature fails for bigger messages (but not all that huge)
      digest_type = :sha512
      rsa_pk_sign_verify_opts = []

      # this is a plain binary, not base64 encoded
      signature = :public_key.sign(message, digest_type, rsa_private_key, rsa_pk_sign_verify_opts)

      rsa_public_key =
        Hoplon.Crypto.Records.rsa_public_key(publicExponent: public_exponent, modulus: modulus)

      assert :public_key.verify(
               message,
               digest_type,
               signature,
               rsa_public_key,
               rsa_pk_sign_verify_opts
             )

      assert :public_key.verify(message, digest_type, signature, rsa_public_key)

      refute :public_key.verify(message <> "x", digest_type, signature, rsa_public_key)
      refute :public_key.verify(message, :sha, signature, rsa_public_key)
      # TODO tests for other cases that shouldn't succeed, once we start using StreamData
    end

    test "verifying a signature from openssh pkeyutl" do
      # commands used:
      # $ openssl dgst -sha512 -binary message.txt > message.digest
      # $ openssl pkeyutl -sign -in message.digest -inkey private.pem -out message.sig -pkeyopt digest:sha512

      public_key_pem_file_contents = File.read!("test/assets/public.pem")
      [rsa_public_key_entry] = :public_key.pem_decode(public_key_pem_file_contents)
      rsa_public_key = :public_key.pem_entry_decode(rsa_public_key_entry)

      # Note, usually the signatures would be encoded in hex, which is something we will do, TODO
      original_message = File.read!("test/assets/message.txt")
      openssl_signature = File.read!("test/assets/message.sig")

      assert :public_key.verify(original_message, :sha512, openssl_signature, rsa_public_key)

      refute :public_key.verify(
               original_message <> "x",
               :sha512,
               openssl_signature,
               rsa_public_key
             )

      refute :public_key.verify(original_message, :sha, openssl_signature, rsa_public_key)
    end
  end
end
