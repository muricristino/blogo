defmodule BlogoWeb.TopicController do
  @moduledoc """
  One page per topic.

  The index listed topics as links to `/?topico=x`, a parameter nothing read —
  they reloaded the index unchanged. Each topic is now an address a search
  engine can index and a reader can share, grouping the articles that answer
  to the same term.
  """
  use BlogoWeb, :controller

  alias Blogo.Content
  alias BlogoWeb.SEO

  def show(conn, %{"slug" => slug}) do
    case Content.posts_by_topic_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> text("Não encontrado")

      topic ->
        base = BlogoWeb.Endpoint.url()
        site = Content.the_site()
        author = Content.the_author()

        conn
        |> assign(:current_author, author)
        |> assign(:nav, :artigos)
        |> assign(:seo, %{
          conn: conn,
          title: "#{topic.name} · #{Content.site_name(site)}",
          description: descricao(topic),
          canonical: "#{base}/tag/#{topic.slug}",
          site_name: Content.site_name(site),
          image: List.first(topic.posts) && "#{base}/imagem/#{List.first(topic.posts).slug}.png",
          json_ld: SEO.topic(topic, base)
        })
        |> render(:show, topic: topic)
    end
  end

  defp descricao(%{name: name, posts: posts}) do
    "#{length(posts)} #{if length(posts) == 1, do: "artigo", else: "artigos"} sobre #{name}."
  end
end
