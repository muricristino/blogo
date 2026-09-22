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

    conn
    |> assign(:current_author, author)
    |> assign(:nav, :artigos)
    |> assign(:seo, %{
      conn: conn,
      title: if(author, do: "#{author.name} · artigos", else: "blogo"),
      description: author && author.headline,
      canonical: base <> "/",
      json_ld: author && SEO.profile_page(author, posts, base)
    })
    |> render(:index,
      posts: rest,
      featured: featured,
      author: author,
      topics: topics(posts),
      total: length(posts),
      most_read: Enum.take(posts, 3),
      series: series()
    )
  end

  def show(conn, %{"slug" => slug}) do
    case Content.get_published_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> text("Não encontrado")

      post ->
        base = base_url(conn)
        {summary, blocks} = Post.for_reading(post)

        conn
        |> assign(:current_author, post.author)
        |> assign(:nav, :artigos)
        |> assign(:progress, true)
        |> assign(:seo, %{
          conn: conn,
          title: "#{post.title} · #{post.author.name}",
          description: post.meta_description || post.subtitle,
          canonical: "#{base}/#{post.slug}",
          type: "article",
          published_at: post.published_at,
          author: post.author,
          json_ld: SEO.article(post, base)
        })
        |> render(:show,
          post: post,
          blocks: blocks,
          summary: summary,
          sections: Enum.filter(blocks, &(&1["type"] == "section"))
        )
    end
  end

  # Séries ainda não têm tabela: são um agrupamento editorial que o autor
  # declara, e enquanto o editor não existe elas moram aqui.
  defp series do
    [
      %{
        title: "Avaliar sem se enganar",
        dek: "Do conjunto de teste ao limiar calibrado.",
        parts: 4,
        done: 2
      },
      %{
        title: "Falhas silenciosas",
        dek: "Os lugares onde um erro não vira log.",
        parts: 3,
        done: 0
      },
      %{
        title: "Rails que aguenta",
        dek: "Consultas, filas e o que quebra primeiro.",
        parts: 5,
        done: 5
      }
    ]
  end

  defp split_featured([]), do: {nil, []}
  defp split_featured([first | rest]), do: {first, rest}

  defp topics(posts) do
    posts
    |> Enum.flat_map(& &1.topics)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_t, n} -> -n end)
  end

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
