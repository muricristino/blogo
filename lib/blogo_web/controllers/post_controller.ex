defmodule BlogoWeb.PostController do
  use BlogoWeb, :controller

  alias Blogo.Content
  alias Blogo.Content.Post
  alias BlogoWeb.SEO

  def index(conn, _params) do
    posts = Content.list_published()
    {featured, rest} = split_featured(posts)
    author = featured && featured.author
    base = base_url(conn)
    site = Content.the_site()

    conn
    |> assign(:current_author, author)
    |> assign(:nav, :artigos)
    |> assign(:seo, %{
      conn: conn,
      title: Content.site_name(site),
      description: site.description || (author && author.headline),
      canonical: base <> "/",
      site_name: Content.site_name(site),
      image: featured && "#{base}/imagem/#{featured.slug}.png",
      json_ld: SEO.site(site, base)
    })
    |> render(:index,
      posts: rest,
      featured: featured,
      author: author,
      topics: Content.list_topics(),
      total: length(posts),
      most_read: Enum.take(posts, 3)
    )
  end

  def show(conn, %{"slug" => slug}) do
    case Content.get_published_by_slug(slug) do
      nil ->
        moved_or_missing(conn, slug)

      post ->
        base = base_url(conn)
        site = Content.the_site()
        {summary, blocks} = Post.for_reading(post)
        page? = post.kind == "pagina"

        conn
        |> assign(:current_author, post.author)
        |> assign(:nav, if(page?, do: :pagina, else: :artigos))
        |> assign(:page_slug, post.slug)
        |> assign(:progress, true)
        |> assign(:seo, %{
          conn: conn,
          title: "#{post.title} · #{Content.site_name(site)}",
          description: post.meta_description || post.subtitle,
          canonical: "#{base}/#{post.slug}",
          image: "#{base}/imagem/#{post.slug}.png",
          type: if(page?, do: "profile", else: "article"),
          site_name: Content.site_name(site),
          published_at: post.published_at,
          author: post.author,
          # A fixed page is where the Person lives; an article carries the same
          # Person inside it as author and publisher.
          json_ld:
            if(page?,
              do: SEO.profile_page(post.author, base),
              else: SEO.article(post, base)
            )
        })
        |> assign(:read_token, BlogoWeb.ReadController.token(post.slug))
        |> render(:show,
          post: post,
          blocks: blocks,
          summary: summary,
          sections: Enum.filter(blocks, &(&1["type"] == "section"))
        )
    end
  end

  # An address that used to belong to a published article answers 301 rather
  # than 404, so a link made years ago still lands on the article it meant.
  defp moved_or_missing(conn, slug) do
    case Content.post_by_former_slug(slug) do
      nil -> conn |> put_status(:not_found) |> text("Não encontrado")
      post -> conn |> put_status(:moved_permanently) |> redirect(to: ~p"/#{post.slug}")
    end
  end

  defp split_featured([]), do: {nil, []}
  defp split_featured([first | rest]), do: {first, rest}

  # The first keynumbers block becomes the "EM RESUMO" card in the header
  # rather than a block in the flow, which is where the canvas puts it.
  # Behind the tunnel `conn.scheme` is http — cloudflared terminates TLS and
  # talks to the container in the clear. Taking the base from the endpoint's
  # configured url instead is what makes the canonical, og:url and every @id in
  # the structured data agree on https. Cloudflare's Automatic HTTPS Rewrites
  # hides the bug in `href` attributes and nowhere else, so the JSON-LD was the
  # only place it showed.
  defp base_url(_conn), do: BlogoWeb.Endpoint.url()
end
