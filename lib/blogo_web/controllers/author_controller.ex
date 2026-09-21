defmodule BlogoWeb.AuthorController do
  use BlogoWeb, :controller

  alias Blogo.Content
  alias BlogoWeb.SEO

  def show(conn, %{"slug" => slug}) do
    case Content.get_author_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> text("Não encontrado")

      author ->
        posts = Content.list_published() |> Enum.filter(&(&1.author_id == author.id))

        base = BlogoWeb.Endpoint.url()

        conn
        |> assign(:current_author, author)
        |> assign(:nav, :sobre)
        |> assign(:seo, %{
          conn: conn,
          title: "#{author.name} · #{author.headline}",
          description: author.bio,
          canonical: "#{base}/autor/#{author.slug}",
          type: "profile",
          json_ld: SEO.profile_page(author, posts, base)
        })
        |> render(:show, author: author, posts: posts)
    end
  end
end
