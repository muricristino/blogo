defmodule BlogoWeb.PostController do
  use BlogoWeb, :controller

  alias Blogo.Content
  alias BlogoWeb.SEO

  def index(conn, _params) do
    posts = Content.list_published()
    author = List.first(posts) |> author_of()
    base = base_url(conn)

    conn
    |> assign(:current_author, author)
    |> assign(:seo, %{
      conn: conn,
      title: title_for(author),
      description: author && author.headline,
      canonical: base <> "/",
      json_ld: author && SEO.profile_page(author, posts, base)
    })
    |> render(:index, posts: posts, author: author)
  end

  def show(conn, %{"slug" => slug}) do
    case Content.get_published_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> text("Não encontrado")

      post ->
        base = base_url(conn)

        conn
        |> assign(:current_author, post.author)
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
        |> render(:show, post: post)
    end
  end

  defp author_of(nil), do: nil
  defp author_of(post), do: post.author

  defp title_for(nil), do: "blogo"
  defp title_for(author), do: "#{author.name} · artigos"

  defp base_url(conn), do: "#{conn.scheme}://#{conn.host}#{port_suffix(conn)}"
  defp port_suffix(%{port: p}) when p in [80, 443], do: ""
  defp port_suffix(%{port: p}), do: ":#{p}"
end
