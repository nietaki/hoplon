defmodule Hoplon.Crypto.Records do
  require Record

  # IO.inspect Record.extract_all(from_lib: "public_key/include/public_key.hrl")
  Record.defrecord(
    :rsa_private_key,
    :RSAPrivateKey,
    Record.extract(:RSAPrivateKey, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :rsa_public_key,
    :RSAPublicKey,
    Record.extract(:RSAPublicKey, from_lib: "public_key/include/public_key.hrl")
  )
end
