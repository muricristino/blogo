defmodule BlogoWeb.SitemapControllerTest do
  use BlogoWeb.ConnCase, async: true

  import Blogo.Fixtures

  alias Blogo.Content

  test "the sitemap carries published posts and the fixed pages", %{conn: conn} do
    p = post()
    body = conn |> get(~p"/sitemap.xml") |> response(200)

    pagina = post(%{kind: "pagina", slug: "sobre-teste"})

    assert body =~ "<loc>#{BlogoWeb.Endpoint.url()}/#{p.slug}</loc>"
    # A page is kept out of every listing, so the sitemap is the only place a
    # crawler meets it.
    assert conn |> get(~p"/sitemap.xml") |> response(200) =~ "/#{pagina.slug}</loc>"
  end

  test "a draft stays out of the sitemap", %{conn: conn} do
    p = post(%{status: "draft"})
    refute conn |> get(~p"/sitemap.xml") |> response(200) =~ p.slug
  end

  test "robots points crawlers at the sitemap", %{conn: conn} do
    body = conn |> get(~p"/robots.txt") |> response(200)
    assert body =~ "Sitemap: #{BlogoWeb.Endpoint.url()}/sitemap.xml"
  end

  describe "robots.txt" do
    test "answers with what the panel was told, not with a fixed file", %{conn: conn} do
      {:ok, _} = Content.update_site(%{"ai_crawlers" => "none"})
      barrado = conn |> get(~p"/robots.txt") |> response(200)

      {:ok, _} = Content.update_site(%{"ai_crawlers" => "both"})
      liberado = conn |> get(~p"/robots.txt") |> response(200)

      assert barrado =~ "User-agent: GPTBot\nDisallow: /"
      assert liberado =~ "User-agent: GPTBot\nAllow: /"
    end

    test "still points every crawler at the sitemap", %{conn: conn} do
      assert conn |> get(~p"/robots.txt") |> response(200) =~
               "Sitemap: #{BlogoWeb.Endpoint.url()}/sitemap.xml"
    end

    test "an install that never chose gets the default, spelled out", %{conn: conn} do
      body = conn |> get(~p"/robots.txt") |> response(200)

      assert body =~ "User-agent: GPTBot\nDisallow: /"
      assert body =~ "User-agent: OAI-SearchBot\nAllow: /"
    end
  end
end
