defmodule BlogoWeb.ApiAuth do
  @moduledoc """
  Guards `/api` with one bearer token, held in `BLOGO_API_TOKEN`.

  The same rule as the editor's password: no token configured means no way in,
  not a way in for everyone. A deployment that forgets the variable answers 403
  to every request, which is the failure that is safe.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case {configured_token(), presented_token(conn)} do
      {nil, _} ->
        deny(conn, 403, "api_disabled", "the API is disabled: BLOGO_API_TOKEN is not set")

      {_, nil} ->
        deny(conn, 401, "unauthorized", "missing bearer token")

      {expected, given} ->
        if Plug.Crypto.secure_compare(given, expected),
          do: conn,
          else: deny(conn, 401, "unauthorized", "invalid bearer token")
    end
  end

  defp configured_token do
    case System.get_env("BLOGO_API_TOKEN") do
      t when is_binary(t) and byte_size(t) > 0 ->
        t

      _ ->
        case Application.get_env(:blogo, :api_token) do
          t when is_binary(t) and byte_size(t) > 0 -> t
          _ -> nil
        end
    end
  end

  defp presented_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] when byte_size(token) > 0 -> String.trim(token)
      _ -> nil
    end
  end

  defp deny(conn, status, code, message) do
    conn
    |> put_resp_header("www-authenticate", "Bearer")
    |> put_status(status)
    |> Phoenix.Controller.json(%{ok: false, error: %{code: code, message: message}})
    |> halt()
  end
end
