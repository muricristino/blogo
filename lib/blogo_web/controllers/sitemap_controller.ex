defmodule BlogoWeb.SitemapController do
  use BlogoWeb, :controller

  alias Blogo.Content

  def index(conn, _params) do
    base = "#{conn.scheme}://#{conn.host}#{if conn.port in [80, 443], do: "", else: ":#{conn.port}"}"
    posts = Content.list_published()

    urls =
      [{base <> "/", nil}] ++
        Enum.map(posts, &{"#{base}/#{&1.slug}", &1.updated_at}) ++
        Enum.map(Enum.uniq_by(posts, & &1.author_id), &{"#{base}/autor/#{&1.author.slug}", nil})

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "\n", &url_entry/1)}
    </urlset>
    """

    conn |> put_resp_content_type("application/xml") |> send_resp(200, body)
  end

  def robots(conn, _params) do
    base = "#{conn.scheme}://#{conn.host}#{if conn.port in [80, 443], do: "", else: ":#{conn.port}"}"

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "User-agent: *\nAllow: /\n\nSitemap: #{base}/sitemap.xml\n")
  end

  defp url_entry({loc, nil}), do: "  <url><loc>#{loc}</loc></url>"

  defp url_entry({loc, at}),
    do: "  <url><loc>#{loc}</loc><lastmod>#{DateTime.to_date(at)}</lastmod></url>"
end
