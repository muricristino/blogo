defmodule BlogoWeb.SitemapController do
  @moduledoc """
  The files nobody reads with their eyes: the sitemap for a search crawler and
  `robots.txt` for every crawler.

  Both are generated from the database on request. A site that publishes an
  article or changes its mind about AI crawlers has nothing to regenerate and
  no file to forget.
  """
  use BlogoWeb, :controller

  alias Blogo.Content
  alias Blogo.Content.Crawlers

  def index(conn, _params) do
    base = BlogoWeb.Endpoint.url()

    posts = Content.list_published()

    # Fixed pages belong here even though they are kept out of the index: a
    # page nobody links from a listing is a page a crawler finds only here.
    urls =
      [{base <> "/", nil}] ++
        Enum.map(posts ++ Content.list_pages(), &{"#{base}/#{&1.slug}", &1.updated_at}) ++
        Enum.map(Content.list_topics(), &{"#{base}/tag/#{&1.slug}", nil})

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "\n", &url_entry/1)}
    </urlset>
    """

    conn |> put_resp_content_type("application/xml") |> send_resp(200, body)
  end

  def robots(conn, _params) do
    body = Crawlers.robots_txt(Content.the_site(), BlogoWeb.Endpoint.url())

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end

  defp url_entry({loc, nil}), do: "  <url><loc>#{loc}</loc></url>"

  defp url_entry({loc, at}),
    do: "  <url><loc>#{loc}</loc><lastmod>#{DateTime.to_date(at)}</lastmod></url>"
end
