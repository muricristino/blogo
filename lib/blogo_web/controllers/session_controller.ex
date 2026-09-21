defmodule BlogoWeb.SessionController do
  use BlogoWeb, :controller

  alias BlogoWeb.AdminAuth

  # The public layout carries the site navigation and the subscribe button;
  # neither belongs on a sign-in page.
  plug :put_layout, html: {BlogoWeb.Layouts, :editor}

  def new(conn, _params), do: conn |> assign(:editor?, true) |> render(:new)

  def create(conn, %{"password" => password}) do
    case AdminAuth.sign_in(conn, password) do
      {:ok, conn} ->
        redirect(conn, to: ~p"/editor")

      :error ->
        conn |> put_flash(:error, "Senha incorreta.") |> assign(:editor?, true) |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> AdminAuth.sign_out()
    |> redirect(to: ~p"/")
  end
end
