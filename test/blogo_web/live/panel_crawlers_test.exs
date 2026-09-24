defmodule BlogoWeb.PanelCrawlersTest do
  @moduledoc """
  The panel is where an install decides what an AI crawler may do with it. The
  decision writes to the database and `robots.txt` answers with it, so each of
  these reads the row back and then reads the file the world sees.

  """
  use BlogoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Blogo.Content

  @password "senha-de-teste"

  setup do
    Application.put_env(:blogo, :admin_password, @password)
    on_exit(fn -> Application.delete_env(:blogo, :admin_password) end)
    :ok
  end

  defp sign_in(conn) do
    conn
    |> Phoenix.ConnTest.post(~p"/auth/login", %{"password" => @password})
    |> Phoenix.ConnTest.recycle()
  end

  defp escolher(live, value) do
    live
    |> element(~s|button[phx-value-ai_crawlers="#{value}"]|)
    |> render_click()
  end

  describe "deciding what an AI crawler may do" do
    test "the four choices are on the screen, each with what it does", %{conn: conn} do
      {:ok, _live, html} = live(sign_in(conn), ~p"/painel")

      assert html =~ "O que crawler de IA pode fazer"
      assert html =~ "Treino e citação"
      assert html =~ "Só citação"
      assert html =~ "Só treino"
      assert html =~ "Nenhum dos dois"
      assert html =~ "Não pode usar o texto para treinar"
    end

    # An install that never answered is not an install that chose the default.
    test "says out loud that nobody has decided yet, and which default applies", %{conn: conn} do
      {:ok, _live, html} = live(sign_in(conn), ~p"/painel")

      assert html =~ "Ninguém decidiu isso ainda"
      assert html =~ "só citação"
    end

    test "the choice reaches the database", %{conn: conn} do
      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")

      escolher(live, "none")

      assert Content.the_site().ai_crawlers == "none"
    end

    test "choosing removes the “nobody decided” note", %{conn: conn} do
      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")

      html = escolher(live, "citation")

      refute html =~ "Ninguém decidiu isso ainda"
      assert Content.the_site().ai_crawlers == "citation"
    end

    test "robots.txt answers with the new choice on the next request", %{conn: conn} do
      signed = sign_in(conn)
      {:ok, live, _html} = live(signed, ~p"/painel")

      escolher(live, "both")

      assert Phoenix.ConnTest.build_conn() |> get(~p"/robots.txt") |> response(200) =~
               "User-agent: GPTBot\nAllow: /"

      escolher(live, "none")

      assert Phoenix.ConnTest.build_conn() |> get(~p"/robots.txt") |> response(200) =~
               "User-agent: GPTBot\nDisallow: /"
    end

    test "the screen says where the rule lives and who it cannot reach", %{conn: conn} do
      {:ok, _live, html} = live(sign_in(conn), ~p"/painel")

      assert html =~ "robots.txt"
      assert html =~ "Gemini lê com o Googlebot"
    end
  end
end
