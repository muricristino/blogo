defmodule BlogoWeb.SitemapControllerTest do
  use BlogoWeb.ConnCase, async: true

  import Blogo.Fixtures

  test "the sitemap carries published posts and their author", %{conn: conn} do
    p = post()
    body = conn |> get(~p"/sitemap.xml") |> response(200)

    assert body =~ "<loc>http://www.example.com/#{p.slug}</loc>"
    assert body =~ "/autor/#{p.author.slug}"
  end

  test "a draft stays out of the sitemap", %{conn: conn} do
    p = post(%{status: "draft"})
    refute conn |> get(~p"/sitemap.xml") |> response(200) =~ p.slug
  end

  test "robots points crawlers at the sitemap", %{conn: conn} do
    body = conn |> get(~p"/robots.txt") |> response(200)
    assert body =~ "Sitemap: http://www.example.com/sitemap.xml"
  end
end
