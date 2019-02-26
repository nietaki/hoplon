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
  require Logger

  @password "test"

  # https://crypto.stackexchange.com/a/10825
  @standard_rsa_public_exponent 65537

  @long_property_test_time_limit_ms 300

  @tmp_dir "test/tmp/"
  @private_key_file @tmp_dir <> "private.pem"
  @public_key_file @tmp_dir <> "public.pem"
  @message_file "test/assets/message.txt"

  @pkey_bit_size_string "4096"

  setup_all do
    if !File.exists?(@private_key_file) do
      Logger.info("Lazily generating private and public key files")

      openssl_opts = [
        "genrsa",
        "-passout",
        "pass:#{@password}",
        "-des3",
        "-out",
        @private_key_file,
        @pkey_bit_size_string
      ]

      openssl(openssl_opts)

      openssl_opts = [
        "rsa",
        "-passin",
        "pass:#{@password}",
        "-in",
        @private_key_file,
        "-outform",
        "PEM",
        "-pubout",
        "-out",
        @public_key_file
      ]

      openssl(openssl_opts)
    end

    :ok
  end

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
    public_key_pem_file_contents = File.read!(@public_key_file)
    assert {:ok, public_key} = Crypto.decode_public_key_from_pem(public_key_pem_file_contents)
    assert Crypto.is_public_key(public_key)

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
    private_key_pem_file_contents = File.read!(@private_key_file)

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
    pem = File.read!(@private_key_file)
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
    pem = File.read!(@private_key_file)

    check all password <- string(:alphanumeric),
              password != @password do
      assert {:error, %Error{code: code}} = Crypto.decode_private_key_from_pem(pem, password)
      assert code == :could_not_decode_pem_with_given_password
    end
  end

  property "trying to decode a public key as if it was a private key, with a random password errors out neatly" do
    pem = File.read!(@public_key_file)

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
    openssl_digest_file = @tmp_dir <> "message.digest"
    openssl_signature_file = @tmp_dir <> "message.sig.hex"

    # openssl dgst -sha512 -binary message.txt > message.digest
    openssl_opts = [
      "dgst",
      "-sha512",
      "-binary",
      @message_file
    ]

    binary_digest = openssl(openssl_opts)
    File.write!(openssl_digest_file, binary_digest, [:write])

    # NOTE: message.sig.hex was obtained as follows:
    # $ openssl pkeyutl -sign -in message.digest -inkey private.pem -hexdump -out message.sig.hex -pkeyopt digest:sha512
    openssl_opts = [
      "pkeyutl",
      "-sign",
      "-in",
      openssl_digest_file,
      "-passin",
      "pass:#{@password}",
      "-inkey",
      @private_key_file,
      "-hexdump",
      "-out",
      openssl_signature_file,
      "-pkeyopt",
      "digest:sha512"
    ]

    openssl(openssl_opts)

    private_key_pem_file_contents = File.read!(@private_key_file)

    assert {:ok, private_key} =
             Crypto.decode_private_key_from_pem(private_key_pem_file_contents, @password)

    message = File.read!(@message_file)

    hoplon_signature_hex =
      Crypto.get_signature(message, private_key)
      |> Crypto.hex_encode!()

    # The file is in the following format:
    #
    # 0000 - 7b 14 14 4e d2 c0 e5 84-91 ae 9a 35 66 e5 f7 90   {..N.......5f...
    # 0010 - 01 d3 76 fb a6 e6 5e 0a-90 94 9a 60 c7 7b 0e 2d   ..v...^....`.{.-
    # 0020 - 36 dd 16 05 e1 95 65 61-58 a8 94 b9 75 13 6b c8   6.....eaX...u.k.
    openssh_signature_hex =
      File.read!(openssl_signature_file)
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
    openssl_opts = [
      "rsa",
      "-in",
      @public_key_file,
      "-pubin",
      "-pubout",
      "-outform",
      "DER"
    ]

    public_key_der_binary = openssl(openssl_opts)
    public_key_der_file = @tmp_dir <> "public.der"
    File.write!(public_key_der_file, public_key_der_binary, [:write])

    extract_hash = fn string ->
      regex = ~r/[0-9a-f]{30,}/
      assert [[hash]] = Regex.scan(regex, string)
      hash
    end

    md5_hash =
      openssl(["dgst", "-md5", public_key_der_file])
      |> extract_hash.()

    sha256_hash =
      openssl(["dgst", "-sha256", public_key_der_file])
      |> extract_hash.()

    sha512_hash =
      openssl(["dgst", "-sha512", public_key_der_file])
      |> extract_hash.()

    public_key_pem = File.read!(@public_key_file)
    assert {:ok, public_key} = Crypto.decode_public_key_from_pem(public_key_pem)

    assert md5_hash == Crypto.get_fingerprint(public_key, :md5)
    assert String.length(md5_hash) == 32
    assert sha256_hash == Crypto.get_fingerprint(public_key, :sha256)
    assert String.length(sha256_hash) == 64
    assert sha512_hash == Crypto.get_fingerprint(public_key, :sha512)
    assert String.length(sha512_hash) == 128
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

  defp openssl(openssl_opts) do
    assert {output, 0} = System.cmd("openssl", openssl_opts)
    output
  end
end
