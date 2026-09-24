defmodule BlogoWeb.SitemapControllerTest do
  use BlogoWeb.ConnCase, async: true

  import Blogo.Fixtures

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
end
