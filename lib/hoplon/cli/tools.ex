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
      {:ok, _env_path} = success ->
        success

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
end
