defmodule Hoplon.ApiClient do
  # base needs to have the scheme!
  def post(base, path, query, body) do
    Application.ensure_started(:inets)
    Application.ensure_started(:ssl)

    url_binary = build_full_url(base, path, query)
    url = String.to_charlist(url_binary)
    headers = []
    body = Jason.encode!(body)
    request = {url, headers, 'application/json', body}

    case :httpc.request(:post, request, [], body_format: :binary) do
      {:ok, response} ->
        {{_http, status_code, _status_name}, response_headers, response_body} = response

        response_body =
          case Jason.decode(response_body) do
            {:ok, decoded} -> decoded
            _ -> response_body
          end

        response_headers = stringify_headers(response_headers)
        {:ok, {status_code, response_headers, response_body}}

      {:error, _} = error ->
        error
    end
  end

  defp stringify_headers(headers) do
    Enum.map(headers, &stringify_header/1)
  end

  defp stringify_header({k, v}), do: {to_string(k), to_string(v)}

  def build_full_url(base, path, query) do
    base = Path.join(base, path)

    suffix =
      case query do
        [] ->
          ""

        [_ | _] ->
          "?" <> URI.encode_query(query)
      end

    base <> suffix
  end
end
