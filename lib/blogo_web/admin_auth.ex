defmodule BlogoWeb.AdminAuth do
  @moduledoc """
  Guards the editor. One password, held in `ADMIN_PASSWORD`.

  The blog has one author, so a users table with registration and password
  reset would be machinery serving nobody. This is deliberately the smallest
  thing that actually locks the door, and it is written down as a decision
  rather than an oversight: the day blogo has a second author, this module is
  what gets replaced, and nothing else has to change.

  Two paths need guarding and they are not the same. The HTTP request is
  checked by `require_admin/2`; the LiveView socket reconnects over a
  websocket, which never re-runs a plug, so `on_mount/4` checks the session
  the plug wrote. Guarding only the first leaves the editor reachable by
  anyone who can open a socket.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  @session_key "admin?"

  def require_admin(conn, _opts) do
    if get_session(conn, @session_key) do
      conn
    else
      conn
      |> put_flash(:error, "Entre para abrir o editor.")
      |> redirect(to: "/entrar")
      |> halt()
    end
  end

  @doc """
  Checks the password and marks the session. The comparison is constant-time:
  a plain `==` on a secret leaks its length and its first differing byte to
  anyone willing to measure.
  """
  def sign_in(conn, password) do
    if valid?(password) do
      {:ok,
       conn
       |> renew_session()
       |> put_session(@session_key, true)}
    else
      :error
    end
  end

  def sign_out(conn), do: renew_session(conn)

  def admin?(conn_or_session)
  def admin?(%Plug.Conn{} = conn), do: !!get_session(conn, @session_key)
  def admin?(%{} = session), do: !!session[@session_key]

  def on_mount(:ensure_admin, _params, session, socket) do
    if admin?(session) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/entrar")}
    end
  end

  defp valid?(password) when is_binary(password) do
    case configured_password() do
      nil -> false
      expected -> Plug.Crypto.secure_compare(password, expected)
    end
  end

  defp valid?(_), do: false

  # No password configured means no way in, rather than a way in for everyone.
  defp configured_password do
    case System.get_env("ADMIN_PASSWORD") do
      p when is_binary(p) and byte_size(p) > 0 -> p
      _ -> Application.get_env(:blogo, :admin_password)
    end
  end

  # A fresh session id on sign-in and sign-out, so a session id captured before
  # the change cannot be replayed after it.
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
