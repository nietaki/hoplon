defmodule Support.Utils do
  alias Hoplon.Data
  require Hoplon.Data
  alias Hoplon.Data.Encoder
  alias Hoplon.CLI.Tools
  alias Hoplon.Crypto

  def random_string(length \\ 12) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
    |> String.replace("-", "_")
  end

  def random_tmp_directory() do
    "/tmp/hoplon_tests/#{random_string(16)}"
  end

  # Mix task testing

  def get_output_lines(opts) do
    mock_io = Keyword.fetch!(opts, :io_device)
    output = StringIO.flush(mock_io)
    String.split(output, "\n", trim: true)
  end

  def mock_input_opts(user_inputs) do
    {:ok, mock_io} = StringIO.open(user_inputs)
    {:ok, mock_stderr} = StringIO.open("")
    [io_device: mock_io, stderr_device: mock_stderr]
  end

  def prepare_fresh_hoplon_env() do
    hoplon_dir = random_tmp_directory()
    env_name = random_string(10)
    System.put_env("HOPLON_DIR", hoplon_dir)
    System.put_env("HOPLON_ENV", env_name)
    {:ok, env_path} = Hoplon.CLI.Tools.bootstrap_hoplon_env(hoplon_dir, env_name)
    env_path
  end

  def generate_random_public_key() do
    %{fingerprint: fingerprint, public_key_path: path, public_pem: public_pem} = test_key()
    {fingerprint, path, public_pem}
  end

  def test_key() do
    alias Hoplon.Crypto
    password = random_string()
    private_key = Crypto.generate_private_key()
    public_key = Crypto.build_public_key(private_key)
    fingerprint = Crypto.get_fingerprint(public_key)

    {:ok, public_pem} = Crypto.encode_public_key_to_pem(public_key)
    {:ok, private_pem} = Crypto.encode_private_key_to_pem(private_key, password)

    dir = "/tmp/hoplon_tests/random_public_keys"
    File.mkdir_p!(dir)
    key_name = "#{random_string()}.pem"
    public_key_path = Path.join(dir, key_name)
    File.write!(public_key_path, public_pem)

    %{
      private_key: private_key,
      public_key: public_key,
      fingerprint: fingerprint,
      password: password,
      public_pem: public_pem,
      private_pem: private_pem,
      public_key_path: public_key_path
    }
  end

  def add_test_key_to_trusted_keys(env_dir, test_key) do
    alias Mix.Tasks.Hoplon.TrustedKeys

    {:ok, _} =
      TrustedKeys.add_trusted_key_fingerprint_to_config(env_dir, test_key.fingerprint, nil)

    {:ok, _} = TrustedKeys.add_pem_to_peer_keys(env_dir, test_key.public_pem)
  end

  def test_audit(kw) do
    valid_keys =
      ~w(ecosystem name version hash verdict comment publicKeyFingerprint createdAt auditedByAuthor)a

    [] = Keyword.keys(kw) -- valid_keys

    defaults = [
      ecosystem: "hexpm",
      name: random_string(),
      version: random_string(),
      hash: random_string(),
      verdict: :safe,
      comment: random_string(),
      publicKeyFingerprint: random_string(),
      createdAt: DateTime.utc_now() |> DateTime.to_unix(:second),
      auditedByAuthor: false
    ]

    values = Keyword.merge(defaults, kw)

    package =
      Data.package(
        ecosystem: values[:ecosystem],
        name: values[:name],
        version: values[:version],
        hash: values[:hash]
      )

    audit =
      Data.audit(
        package: package,
        verdict: values[:verdict],
        comment: values[:comment],
        publicKeyFingerprint: values[:publicKeyFingerprint],
        createdAt: values[:createdAt],
        auditedByAuthor: values[:auditedByAuthor]
      )

    {:ok, encoded_audit} = Encoder.encode(audit)
    {:ok, encoded_package} = Encoder.encode(package)

    %{
      package_name: values[:name],
      package_hash: values[:hash],
      package: package,
      audit: audit,
      encoded_audit: encoded_audit,
      encoded_package: encoded_package
    }
  end

  def store_signed_audit(env_dir, audit, key) do
    signature = Crypto.get_signature(audit.encoded_audit, key.private_key)
    package_name = audit.package_name
    package_hash = audit.package_hash
    fingerprint = key.fingerprint

    audit_dir = Tools.audit_dir(env_dir, package_name, package_hash)
    :ok = File.mkdir_p(audit_dir)

    audit_path = Tools.audit_path(env_dir, package_name, package_hash, fingerprint)
    sig_path = Tools.sig_path(env_dir, package_name, package_hash, fingerprint)

    :ok = File.write(audit_path, audit.encoded_audit)
    :ok = File.write(sig_path, signature)

    {:ok, signature}
  end
end
