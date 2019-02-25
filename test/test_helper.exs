tmp_dir = "test/tmp/"

# TODO do this lazily in the crypto test setup
IO.puts("# Setting up test files...")

private_key_file = tmp_dir <> "private.pem"
_public_key_file = tmp_dir <> "public.pem"

IO.puts("## Generating a test private key")

{"", 0} =
  System.cmd("openssl", ~w(genrsa -passout pass:test -des3 -out) ++ [private_key_file, "4096"])

IO.puts("# DONE!")

ExUnit.start()
