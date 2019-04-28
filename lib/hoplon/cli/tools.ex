defmodule Hoplon.CLI.Tools do
  def bootstrap_hoplon_env(hoplon_dir_path, env_name) do
    env_path = Path.join(hoplon_dir_path, env_name)
    peer_keys_path = Path.join(env_path, "peer_keys")
    audits_path = Path.join(env_path, "audits")
    config_path = Path.join(env_path, "config.exs")

    with {:ok, _} <- validate_env_name(env_name),
         :ok <- File.mkdir_p(env_path),
         :ok <- File.mkdir_p(peer_keys_path),
         :ok <- File.mkdir_p(audits_path),
         Hoplon.CLI.ConfigFile.read_or_create!(config_path) do
      {:ok, env_path}
    end
  end

  def bootstrap_hoplon_env!(hoplon_dir_path, env_name) do
    case bootstrap_hoplon_env(hoplon_dir_path, env_name) do
      {:ok, env_path} ->
        env_path

      {:error, reason} ->
        Mix.raise(inspect(reason))

      _ ->
        Mix.raise("error when bootstraping hoplon env")
    end
  end

  defp validate_env_name(env_name) do
    if env_name =~ ~r/^[a-zA-Z0-9_-]+$/ do
      {:ok, env_name}
    else
      {:error, :invalid_env_name}
    end
  end

  def private_key_path(env_path) do
    Path.join(env_path, "my.private.pem")
  end

  def public_key_path(env_path) do
    Path.join(env_path, "my.public.pem")
  end

  def config_file_path(env_path) do
    Path.join(env_path, "config.exs")
  end

  def audit_path(env_path, package_name, package_hash, key_fingerprint) do
    filename = "#{key_fingerprint}.audit"
    Path.join(audit_dir(env_path, package_name, package_hash), filename)
  end

  def sig_path(env_path, package_name, package_hash, key_fingerprint) do
    filename = "#{key_fingerprint}.sig"
    Path.join(audit_dir(env_path, package_name, package_hash), filename)
  end

  def audit_dir(env_path, package_name, package_hash) do
    Path.join([env_path, package_name, package_hash])
  end

  def get_peer_key_path(env_path, key_fingerprint) do
    if Regex.match?(~r/^[0-9a-f]{30,}$/, key_fingerprint) do
      path = Path.join([env_path, "peer_keys", "#{key_fingerprint}.public.pem"])
      {:ok, path}
    else
      {:error, :invalid_key_fingerprint}
    end
  end

  def print_and_get_env_path(switches, opts) do
    alias Hoplon.CLI.Prompt
    hoplon_dir = Keyword.fetch!(switches, :hoplon_dir)
    hoplon_env = Keyword.fetch!(switches, :hoplon_env)
    Prompt.puts("hoplon_dir: #{hoplon_dir}", opts)
    Prompt.puts("hoplon_env: #{hoplon_env}", opts)
    bootstrap_hoplon_env!(hoplon_dir, hoplon_env)
  end

  def extract_or_raise({:ok, value}, _message) do
    value
  end

  def extract_or_raise(_error, message) do
    Mix.raise(message)
  end
end
