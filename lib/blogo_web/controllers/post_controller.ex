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
        blocks = Post.blocks(post)
        {summary, blocks} = pop_summary(blocks)
        blocks = number_sections(blocks)

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
      %{title: "Avaliar sem se enganar", dek: "Do conjunto de teste ao limiar calibrado.", parts: 4, done: 2},
      %{title: "Falhas silenciosas", dek: "Os lugares onde um erro não vira log.", parts: 3, done: 0},
      %{title: "Rails que aguenta", dek: "Consultas, filas e o que quebra primeiro.", parts: 5, done: 5}
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
  defp pop_summary(blocks) do
    case Enum.split_while(blocks, &(&1["type"] != "keynumbers")) do
      {before, [summary | rest]} -> {summary, before ++ rest}
      {all, []} -> {nil, all}
    end
  end

  # Anchors are derived, not authored: an editor renaming a section should not
  # have to remember to renumber the table of contents.
  defp number_sections(blocks) do
    {blocks, _} =
      Enum.map_reduce(blocks, 0, fn
        %{"type" => "section"} = b, n ->
          n = n + 1
          {Map.merge(b, %{"n" => String.pad_leading("#{n}", 2, "0"), "id" => "sec-#{n}"}), n}

        b, n ->
          {b, n}
      end)

    blocks
  end

  defp base_url(conn), do: "#{conn.scheme}://#{conn.host}#{port_suffix(conn)}"
  defp port_suffix(%{port: p}) when p in [80, 443], do: ""
  defp port_suffix(%{port: p}), do: ":#{p}"
end
