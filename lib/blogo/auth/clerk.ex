defmodule Blogo.Auth.Clerk do
  @moduledoc """
  Verifies a Clerk session, the same way codo and webo do: the login happens in
  the browser with Clerk's SDK, and this side only verifies — RS256 against
  this instance's JWKS, plus expiry.

  Two modes, decided by the environment: no keys means `ADMIN_PASSWORD`, both
  keys mean Google through Clerk. One key without the other is refused at boot,
  because a half-configured login that falls back to a password is a door
  everyone believes is locked.

  `BLOGO_ALLOWED_EMAILS` has the last word over Clerk.
  """

  require Logger

  @jwks_ttl :timer.hours(1)
  @http_timeout 10_000

  @doc """
  `:clerk` or `:password`. Raises when exactly one key is set — that is a
  mistake, not a choice.
  """
  def mode do
    case {publishable_key(), secret_key()} do
      {nil, nil} ->
        :password

      {pk, sk} when is_binary(pk) and is_binary(sk) ->
        :clerk

      {nil, _} ->
        raise "CLERK_SECRET_KEY está definida e CLERK_PUBLISHABLE_KEY não — configure as duas ou nenhuma"

      {_, nil} ->
        raise "CLERK_PUBLISHABLE_KEY está definida e CLERK_SECRET_KEY não — configure as duas ou nenhuma"
    end
  end

  def configured?, do: mode() == :clerk

  def publishable_key, do: env("CLERK_PUBLISHABLE_KEY")
  defp secret_key, do: env("CLERK_SECRET_KEY")

  defp env(name) do
    case System.get_env(name) || Application.get_env(:blogo, :"#{String.downcase(name)}") do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          trimmed -> trimmed
        end

      _ ->
        nil
    end
  end

  @doc """
  The Clerk host, decoded from the publishable key (base64 after the prefix).
  Taking it from the key means the SDK is loaded from, and the token verified
  against, the same instance — no third host to get wrong.
  """
  def frontend_api(pk \\ nil) do
    pk = pk || publishable_key()

    with true <- is_binary(pk),
         [_, encoded] <- Regex.run(~r/^pk_(?:test|live)_(.+)$/, pk),
         {:ok, decoded} <- Base.decode64(encoded, padding: false) do
      {:ok, String.trim_trailing(decoded, "$")}
    else
      _ -> {:error, "CLERK_PUBLISHABLE_KEY não parece uma chave do Clerk (pk_test_… / pk_live_…)"}
    end
  end

  @doc """
  Verifies a session token and returns the person it belongs to. The allowlist
  is applied last, so it overrides Clerk saying yes.
  """
  def session_user(token) when is_binary(token) do
    with {:ok, claims} <- verify(token),
         {:ok, user} <- fetch_user(claims["sub"]),
         :ok <- check_allowed(user.email) do
      {:ok, user}
    end
  end

  def session_user(_), do: {:error, "sessão ausente"}

  @doc """
  The allowlist has the last word. With none configured, Clerk decides alone —
  acceptable only because a Clerk instance is invite-only.
  """
  def check_allowed(email) do
    case allowed_emails() do
      nil ->
        :ok

      list ->
        if String.downcase(email) in list,
          do: :ok,
          else: {:error, "#{email} não está em BLOGO_ALLOWED_EMAILS"}
    end
  end

  defp allowed_emails do
    case env("BLOGO_ALLOWED_EMAILS") do
      nil ->
        nil

      raw ->
        raw
        |> String.split(",")
        |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
        |> Enum.reject(&(&1 == ""))
        |> case do
          [] -> nil
          list -> list
        end
    end
  end

  # ── verifying the token ───────────────────────────────────────────────────

  defp verify(token) do
    with {:ok, kid} <- kid_of(token),
         {:ok, jwk} <- key_for(kid) do
      signer = Joken.Signer.create("RS256", jwk)

      # `aud` is deliberately not checked: a Clerk session's audience varies by
      # setup, and what authenticates the token is the signature against *this*
      # instance plus expiry. Same call codo and webo make.
      case Joken.verify_and_validate(%{}, token, signer) do
        {:ok, claims} -> check_expiry(claims)
        {:error, reason} -> {:error, "sessão recusada: #{inspect(reason)}"}
      end
    end
  end

  defp check_expiry(claims) do
    now = System.system_time(:second)
    # Ten seconds of leeway for clock skew.
    exp = claims["exp"]
    nbf = claims["nbf"]

    cond do
      is_integer(exp) and now > exp + 10 -> {:error, "sessão expirada"}
      is_integer(nbf) and now < nbf - 10 -> {:error, "sessão ainda não é válida"}
      true -> {:ok, claims}
    end
  end

  defp kid_of(token) do
    case Joken.peek_header(token) do
      {:ok, %{"kid" => kid}} when is_binary(kid) -> {:ok, kid}
      {:ok, _} -> {:error, "o token não traz kid"}
      {:error, _} -> {:error, "token malformado"}
    end
  end

  # Cached for an hour; an unknown kid (key rotation) refetches immediately
  # rather than failing until the cache expires.
  defp key_for(kid) do
    case cached_jwks() do
      %{^kid => jwk} -> {:ok, jwk}
      _ -> refresh_jwks(kid)
    end
  end

  defp cached_jwks do
    case :persistent_term.get({__MODULE__, :jwks}, nil) do
      {fetched_at, keys} ->
        if System.monotonic_time(:millisecond) - fetched_at < @jwks_ttl, do: keys, else: nil

      _ ->
        nil
    end
  end

  defp refresh_jwks(kid) do
    with {:ok, host} <- frontend_api(),
         {:ok, body} <- get_json("https://#{host}/.well-known/jwks.json"),
         %{"keys" => keys} when is_list(keys) <- body do
      parsed = Map.new(keys, fn %{"kid" => k} = jwk -> {k, jwk} end)
      :persistent_term.put({__MODULE__, :jwks}, {System.monotonic_time(:millisecond), parsed})

      case parsed do
        %{^kid => jwk} -> {:ok, jwk}
        _ -> {:error, "a chave #{inspect(kid)} não está no JWKS desta instância"}
      end
    else
      {:error, reason} -> {:error, "não foi possível ler o JWKS do Clerk: #{reason}"}
      _ -> {:error, "o JWKS do Clerk não veio no formato esperado"}
    end
  end

  # ── the person behind the session ─────────────────────────────────────────

  defp fetch_user(nil), do: {:error, "a sessão não identifica ninguém"}

  defp fetch_user(user_id) do
    case get_json("#{api_base()}/v1/users/#{user_id}", [
           {"authorization", "Bearer #{secret_key()}"}
         ]) do
      {:ok, raw} -> {:ok, to_user(raw)}
      {:error, reason} -> {:error, "não foi possível ler o usuário no Clerk: #{reason}"}
    end
  end

  defp to_user(raw) do
    primary = raw["primary_email_address_id"]

    email =
      (raw["email_addresses"] || [])
      |> Enum.find(&(&1["id"] == primary))
      |> case do
        %{"email_address" => address} ->
          address

        _ ->
          raw
          |> Map.get("email_addresses", [])
          |> List.first()
          |> then(&(&1 && &1["email_address"]))
      end

    %{
      id: raw["id"],
      email: email || "",
      name:
        [raw["first_name"], raw["last_name"]]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" ")
        |> String.trim(),
      avatar: raw["image_url"]
    }
  end

  defp api_base, do: env("CLERK_API_BASE") || "https://api.clerk.com"

  # ── http ──────────────────────────────────────────────────────────────────

  defp get_json(url, headers \\ []) do
    request = Finch.build(:get, url, headers)

    case Finch.request(request, Blogo.Finch, receive_timeout: @http_timeout) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, "resposta não é JSON"}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc false
  # Tests install a JWKS without a network round trip.
  def put_jwks_cache(keys) do
    :persistent_term.put({__MODULE__, :jwks}, {System.monotonic_time(:millisecond), keys})
  end

  @doc false
  def clear_jwks_cache, do: :persistent_term.erase({__MODULE__, :jwks})
end
