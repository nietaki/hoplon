defmodule Hoplon.CryptoTest do
  use ExUnit.Case
  require Hoplon.Crypto.Records

  @password 'test'

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
    modulus = Hoplon.Crypto.Records.rsa_private_key(rsa_private_key, :modulus)

    assert rsa_public_key ==
             Hoplon.Crypto.Records.rsa_public_key(
               publicExponent: public_exponent,
               modulus: modulus
             )

    Hoplon.Crypto.Records.rsa_public_key()
  end
end
