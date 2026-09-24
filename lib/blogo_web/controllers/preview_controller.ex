defmodule BlogoWeb.PreviewController do
  @moduledoc """
  Shows a draft through the public article template.

  It renders the saved post, not the editor's in-memory state, so what opens in
  the new tab is exactly what a reader would get — including anything the
  writer has typed but not yet saved being absent, which is itself worth
  seeing.

  Drafts are excluded from the sitemap and carry `noindex`, so opening this
  page does not put an unfinished article into a search index.
  """
  use BlogoWeb, :controller

  alias Blogo.Content

  def show(conn, %{"id" => id}) do
    post = Content.get_post!(id)
    {summary, blocks} = Blogo.Content.Post.for_reading(post)

    conn
    |> put_layout(html: {BlogoWeb.Layouts, :app})
    |> put_view(BlogoWeb.PostHTML)
    |> assign(:nav, :artigos)
    |> assign(:current_author, post.author)
    |> assign(:progress, true)
    |> assign(:preview?, true)
    |> render(:show,
      post: post,
      blocks: blocks,
      summary: summary,
      sections: Enum.filter(blocks, &(&1["type"] == "section")),
      series: Blogo.Content.series_of(post),
      page_title: post.title
    )
  end
end
