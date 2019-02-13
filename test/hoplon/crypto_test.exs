defmodule Hoplon.CryptoTest do
  use ExUnit.Case
  require Hoplon.Crypto.Records
  require Record

  @password 'test'
  # https://crypto.stackexchange.com/a/10825
  @standard_rsa_public_exponent 65537

  test "interacting with pem keys generated using openssl" do
    # the keys were generated using the following commands:
    # $ openssl genrsa -des3 -out private.pem 2048
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

    rsa_private_key = :public_key.pem_entry_decode(rsa_private_key_entry, @password)
    assert is_tuple(rsa_private_key)
    assert :RSAPrivateKey = elem(rsa_private_key, 0)

    assert is_integer(Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :modulus))

    # public key
    public_key_pem_file_contents = File.read!("test/assets/public.pem")
    entries = :public_key.pem_decode(public_key_pem_file_contents)
    assert [rsa_public_key_entry] = entries

    assert {:SubjectPublicKeyInfo, der, :not_encrypted} = rsa_public_key_entry
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
    refute :public_key.verify(original_message <> "x", :sha512, openssl_signature, rsa_public_key)
    refute :public_key.verify(original_message, :sha, openssl_signature, rsa_public_key)
  end
end
