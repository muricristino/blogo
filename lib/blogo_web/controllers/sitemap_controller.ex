defmodule BlogoWeb.SitemapController do
  @moduledoc """
  The three files nobody reads with their eyes: the sitemap for a search
  crawler, `robots.txt` for every crawler, and `llms.txt` for whatever is
  feeding a generative model.

  All three are generated from the database on request. A site that renames
  itself, publishes an article or changes its mind about AI crawlers has
  nothing to regenerate and no file to forget.
  """
  use BlogoWeb, :controller

  alias Blogo.Content
  alias Blogo.Content.{Crawlers, Llms}

  def index(conn, _params) do
    base = BlogoWeb.Endpoint.url()

    # Every version in every language, not one per article: each translation is
    # its own address with its own text, and a crawler that never sees the
    # English one cannot index it. Fixed pages are here too — a page no listing
    # links to is a page a crawler finds only here.
    posts = Content.list_all_published()

    urls =
      [{base <> "/", nil}] ++
        Enum.map(posts, &{"#{base}/#{&1.slug}", &1.updated_at}) ++
        Enum.map(Content.list_topics(), &{"#{base}/tag/#{&1.slug}", nil})

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "\n", &url_entry/1)}
    </urlset>
    """

    conn |> put_resp_content_type("application/xml") |> send_resp(200, body)
  end

  @doc """
  The web app manifest: what Android reads to make a shortcut.

  Generated like everything else here rather than written as a file, because the
  site's name comes from the panel. A manifest with a name baked into it would
  be the one thing about the installation that does not obey the panel — and the
  place where it shows is a person's home screen.

  The icons are `maskable`: Android crops a shortcut icon to whatever shape the
  launcher uses, so the mark sits inside the safe zone with the background
  running to the edges.
  """
  def manifest(conn, _params) do
    site = Content.the_site()
    name = Content.site_name(site)

    body =
      Jason.encode!(%{
        name: name,
        short_name: name,
        description: site.description,
        start_url: "/",
        display: "browser",
        background_color: "#0a1120",
        theme_color: "#2563eb",
        icons: [
          %{src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any maskable"},
          %{src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable"}
        ]
      })

    conn |> put_resp_content_type("application/manifest+json") |> send_resp(200, body)
  end

  def robots(conn, _params) do
    body = Crawlers.robots_txt(Content.the_site(), BlogoWeb.Endpoint.url())

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end

  @doc """
  The site's map for a generative model.

  An install that answered "no AI crawler at all" does not serve it: a file
  whose only audience is a model has no business existing next to a robots.txt
  that tells every model to stay out. That is one decision, in one place, with
  the same answer on both surfaces.
  """
  def llms(conn, _params) do
    site = Content.the_site()

    if Crawlers.policy(site) == "none" do
      conn |> put_status(:not_found) |> text("Não encontrado")
    else
      body =
        Llms.llms_txt(%{
          site: site,
          author: Content.the_author(),
          posts: Content.list_published(),
          pages: Content.list_pages(),
          base_url: BlogoWeb.Endpoint.url()
        })

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, body)
    end
  end

  defp url_entry({loc, nil}), do: "  <url><loc>#{loc}</loc></url>"

  defp url_entry({loc, at}),
    do: "  <url><loc>#{loc}</loc><lastmod>#{DateTime.to_date(at)}</lastmod></url>"
end
