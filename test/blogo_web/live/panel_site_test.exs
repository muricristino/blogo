defmodule BlogoWeb.PanelSiteTest do
  @moduledoc """
  The panel decides whether the featured card on the home page draws the
  article's diagram. Every test here clicks the control the way a browser does
  and then reads the row back from the database — the panel agreeing with itself
  is not the same as the choice having been saved.
  """
  use BlogoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Blogo.Content
  alias Blogo.Fixtures

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

  describe "the figure on the featured card" do
    test "says in words what the default is", %{conn: conn} do
      {:ok, _live, html} = live(sign_in(conn), ~p"/painel")

      assert html =~ "Figura no card em destaque"
      assert html =~ "Ligada por padrão"
    end

    # Clicking the element and not firing the event by hand: a `phx-value-value`
    # collision with the <button>'s own property already left two selectors on
    # this screen dead in the browser while the tests passed.
    test "turning it off writes to the database", %{conn: conn} do
      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")

      live |> element("button[phx-value-ligado=false]") |> render_click()

      assert Content.the_site().featured_hero == false
    end

    test "and turning it back on writes too", %{conn: conn} do
      {:ok, _} = Content.update_site(%{"featured_hero" => "false"})
      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")

      live |> element("button[phx-value-ligado=true]") |> render_click()

      assert Content.the_site().featured_hero == true
    end

    # The switch saves on the click. It shows which state is current without a
    # reload, or the next click is made against what the screen used to say.
    test "the screen shows the state that was saved", %{conn: conn} do
      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")

      live |> element("button[phx-value-ligado=false]") |> render_click()

      assert live |> element("button[phx-value-ligado=false].is-on") |> has_element?()
      refute live |> element("button[phx-value-ligado=true].is-on") |> has_element?()
    end

    test "the saved choice reaches the public home page", %{conn: conn} do
      Fixtures.post(%{
        title: "O destaque",
        hero: %{"form" => "fluxo", "data" => %{"steps" => []}, "alt" => "Dois caminhos medidos"}
      })

      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")
      live |> element("button[phx-value-ligado=false]") |> render_click()

      html = build_conn() |> get(~p"/") |> html_response(200)
      refute html =~ "Dois caminhos medidos"
      assert html =~ "feat--plain"
    end

    # The name and the description live in a form with its own Salvar. The
    # switch is outside it so that flipping it cannot discard a name that is
    # half typed.
    test "flipping it does not disturb a name being edited", %{conn: conn} do
      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")
      render_click(live, "site_abrir", %{})

      live
      |> form("form[phx-submit=site_salvar]", %{"site" => %{"name" => "Meio digitado"}})
      |> render_change()

      html = live |> element("button[phx-value-ligado=false]") |> render_click()

      assert html =~ "Meio digitado"
    end
  end
end
