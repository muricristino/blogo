defmodule BlogoWeb.PageControllerTest do
  @moduledoc """
  A fixed page is an article that stays out of the listings, and the old author
  address now points at it. These check the two halves of that: what a page is
  kept out of, and where `/autor/:slug` lands.
  """
  use BlogoWeb.ConnCase

  import Blogo.Fixtures

  defp page(attrs \\ %{}) do
    post(Map.merge(%{kind: "pagina", title: "Sobre", slug: "sobre"}, attrs))
  end

  describe "a page stays out of the listings" do
    test "the index lists articles and not pages", %{conn: conn} do
      artigo = post(%{title: "Um ensaio medido"})
      page()

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ artigo.title
      refute Enum.any?(Blogo.Content.list_published(), &(&1.kind == "pagina"))
    end

    test "the feed carries articles and not pages", %{conn: conn} do
      artigo = post(%{title: "Um ensaio medido"})
      page()

      body = conn |> get(~p"/feed.xml") |> response(200)

      assert body =~ artigo.title
      refute body =~ "<title>Sobre</title>"
    end

    test "a topic page carries articles and not pages", %{conn: conn} do
      post(%{title: "Um ensaio medido", topics: ["método"]})
      page(%{topics: ["método"]})

      html = conn |> get(~p"/tag/metodo") |> html_response(200)

      # "Sobre" is a nav and footer link on every page, so counting the items
      # is what says whether the page slipped into the listing.
      assert html =~ "Um ensaio medido"
      assert html |> String.split(~s(class="listing-item")) |> length() == 2
    end

    # The page is reachable at its own address like any article.
    test "the page itself is served", %{conn: conn} do
      page()
      assert conn |> get(~p"/sobre") |> html_response(200) =~ "Sobre"
    end
  end

  describe "the navigation" do
    test "shows a link for each page, named by its title", %{conn: conn} do
      page(%{title: "Sobre mim", slug: "sobre-mim"})

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(href="/sobre-mim")
      assert html =~ "Sobre mim"
    end

    # A "Sobre" that leads nowhere is worse than no "Sobre".
    test "shows no link when there is no page", %{conn: conn} do
      post()
      refute conn |> get(~p"/") |> html_response(200) =~ ~s(class="navlink" href="/sobre")
    end
  end

  describe "the old author address" do
    test "redirects to the page", %{conn: conn} do
      p = page()
      author = Blogo.Repo.one!(Blogo.Content.Author)

      conn = get(conn, ~p"/autor/#{author.slug}")

      assert redirected_to(conn) == "/#{p.slug}"
    end

    test "is not found when no page has been written", %{conn: conn} do
      author = Blogo.Fixtures.author()
      assert conn |> get(~p"/autor/#{author.slug}") |> response(404)
    end

    test "is not found for an author who does not exist", %{conn: conn} do
      page()
      assert conn |> get(~p"/autor/ninguem") |> response(404)
    end
  end

  describe "the structured data" do
    # The Person is the mechanism the whole project rests on; it must survive
    # the author page becoming an article.
    test "the page carries the Person", %{conn: conn} do
      p = page()
      html = conn |> get(~p"/#{p.slug}") |> html_response(200)

      assert html =~ ~s("@type":"ProfilePage")
      assert html =~ ~s("@type":"Person")
      assert html =~ p.author.name
    end

    test "an article still carries the Person as its author", %{conn: conn} do
      p = post()
      html = conn |> get(~p"/#{p.slug}") |> html_response(200)

      assert html =~ ~s("@type":"Person")
      assert html =~ "#person"
    end

    test "the home page describes the site", %{conn: conn} do
      post()
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s("@type":"WebSite")
    end
  end
end
