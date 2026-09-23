defmodule Blogo.Auth.ClerkTest do
  @moduledoc """
  The verification side, which is all this half of the login does.

  A real Clerk instance is not needed to test it: what the server checks is a
  signature against a JWKS, so the test signs its own tokens with a key it
  generated and installs the matching JWKS. That exercises the same path a
  real token takes — and, more importantly, the paths a forged one takes.
  """
  use ExUnit.Case, async: false

  alias Blogo.Auth.Clerk

  # A Clerk publishable key is the instance host in base64.
  @host "example.clerk.accounts.dev"
  @pk "pk_test_" <> Base.encode64(@host <> "$", padding: false)

  setup do
    jwk = JOSE.JWK.generate_key({:rsa, 2048})
    {_, public} = JOSE.JWK.to_public_map(jwk)
    kid = "test-key"

    Clerk.put_jwks_cache(%{kid => Map.put(public, "kid", kid)})
    Application.put_env(:blogo, :clerk_publishable_key, @pk)

    on_exit(fn ->
      Clerk.clear_jwks_cache()
      Application.delete_env(:blogo, :clerk_publishable_key)
      Application.delete_env(:blogo, :clerk_secret_key)
      Application.delete_env(:blogo, :blogo_allowed_emails)
    end)

    %{jwk: jwk, kid: kid}
  end

  defp token(ctx, claims \\ %{}) do
    claims =
      Map.merge(%{"sub" => "user_123", "exp" => System.system_time(:second) + 600}, claims)

    {_, signed} =
      ctx.jwk
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => ctx.kid}, claims)
      |> JOSE.JWS.compact()

    signed
  end

  describe "the mode" do
    test "is password when no keys are configured" do
      Application.delete_env(:blogo, :clerk_publishable_key)

      assert Clerk.mode() == :password
      refute Clerk.configured?()
    end

    test "is clerk when both keys are configured" do
      Application.put_env(:blogo, :clerk_secret_key, "sk_test_x")
      assert Clerk.mode() == :clerk
    end

    # A login that looks configured and quietly falls back to a password is a
    # door everyone believes is locked.
    test "one key without the other is refused, not guessed at" do
      Application.put_env(:blogo, :clerk_secret_key, "sk_test_x")
      Application.delete_env(:blogo, :clerk_publishable_key)

      assert_raise RuntimeError, ~r/CLERK_PUBLISHABLE_KEY/, &Clerk.mode/0
    end
  end

  describe "the instance host" do
    test "is decoded from the publishable key" do
      assert {:ok, @host} = Clerk.frontend_api(@pk)
    end

    test "a key that is not a Clerk key is reported" do
      assert {:error, message} = Clerk.frontend_api("nada disso")
      assert message =~ "pk_test_"
    end
  end

  describe "verifying a session" do
    test "a token signed by this instance's key passes the signature check", ctx do
      # Resolving the person needs the Clerk API, so the failure here is about
      # the user lookup — which means the signature and the expiry passed.
      assert {:error, reason} = Clerk.session_user(token(ctx))
      refute reason =~ "recusada"
      refute reason =~ "expirada"
    end

    test "a token signed by another key is refused", ctx do
      other = JOSE.JWK.generate_key({:rsa, 2048})

      {_, forged} =
        other
        |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => ctx.kid}, %{
          "sub" => "user_123",
          "exp" => System.system_time(:second) + 600
        })
        |> JOSE.JWS.compact()

      assert {:error, reason} = Clerk.session_user(forged)
      assert reason =~ "recusada"
    end

    test "an expired token is refused", ctx do
      expired = token(ctx, %{"exp" => System.system_time(:second) - 3600})

      assert {:error, reason} = Clerk.session_user(expired)
      assert reason =~ "expirada" or reason =~ "recusada"
    end

    test "a token whose key is unknown to this instance is refused", ctx do
      Clerk.put_jwks_cache(%{"outra-chave" => %{"kid" => "outra-chave"}})

      assert {:error, _} = Clerk.session_user(token(ctx))
    end

    test "garbage is refused without raising" do
      assert {:error, _} = Clerk.session_user("isto.nao.e.um.jwt")
      assert {:error, _} = Clerk.session_user("")
      assert {:error, _} = Clerk.session_user(nil)
    end
  end

  describe "the allowlist" do
    test "lets anyone through when it is not configured" do
      assert :ok = Clerk.check_allowed("qualquer@exemplo.com")
    end

    test "refuses an address that is not on it" do
      Application.put_env(:blogo, :blogo_allowed_emails, "muri@exemplo.com")

      assert :ok = Clerk.check_allowed("muri@exemplo.com")
      assert {:error, _} = Clerk.check_allowed("outro@exemplo.com")
    end

    test "ignores case and spacing, because a list is typed by hand" do
      Application.put_env(:blogo, :blogo_allowed_emails, " Muri@Exemplo.com , outro@exemplo.com ")

      assert :ok = Clerk.check_allowed("muri@exemplo.com")
      assert :ok = Clerk.check_allowed("OUTRO@exemplo.com")
      assert {:error, _} = Clerk.check_allowed("terceiro@exemplo.com")
    end
  end
end
