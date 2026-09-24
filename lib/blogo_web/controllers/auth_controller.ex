defmodule BlogoWeb.AuthController do
  @moduledoc """
  The way in, at `/auth/login`.

  Nothing on the public site links here. A reader has no account to sign into —
  the blog is public and writing in it is not — so a "Entrar" in the navigation
  would be an invitation to a door that is not for them.

  With Clerk configured the page mounts Clerk's own sign-in component, and the
  browser posts the resulting session token to `/auth/session`, which verifies
  it and puts the result in the Phoenix session. The token itself is never
  stored: what survives the request is an email that was proven, once.

  Without Clerk keys the same page asks for `ADMIN_PASSWORD`, which is what a
  fresh clone and the test suite get.
  """
  use BlogoWeb, :controller

  require Logger

  alias Blogo.Auth.Clerk
  alias BlogoWeb.AdminAuth

  plug :put_layout, html: {BlogoWeb.Layouts, :editor}

  def new(conn, _params) do
    conn
    |> assign(:admin?, true)
    |> assign(:mode, Clerk.mode())
    |> assign(:publishable_key, Clerk.publishable_key())
    |> render(:new)
  end

  @doc """
  Receives the Clerk session token from the browser and, if it holds up, signs
  the person in.
  """
  def session(conn, %{"token" => token}) do
    case Clerk.session_user(token) do
      {:ok, user} ->
        conn
        |> AdminAuth.sign_in_user(user)
        |> json(%{ok: true, redirect: ~p"/painel"})

      {:error, reason} ->
        # The reason is logged, not returned: a sign-in page that explains
        # precisely why it refused is a page that helps someone guess.
        Logger.warning("login recusado: #{reason}")

        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: "Esta conta não tem acesso ao blogo."})
    end
  end

  @doc """
  The password mode, for a clone with no Clerk instance behind it.
  """
  def password(conn, %{"password" => password}) do
    case AdminAuth.sign_in(conn, password) do
      {:ok, conn} ->
        redirect(conn, to: ~p"/painel")

      :error ->
        conn
        |> put_flash(:error, "Senha incorreta.")
        |> assign(:admin?, true)
        |> assign(:mode, Clerk.mode())
        |> assign(:publishable_key, Clerk.publishable_key())
        |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> AdminAuth.sign_out()
    |> redirect(to: ~p"/")
  end
end
