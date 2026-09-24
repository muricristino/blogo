defmodule BlogoWeb.PageController do
  @moduledoc """
  What is left of the old author page.

  `/autor/:slug` used to render a template of its own, listing the author's
  articles. It is now a redirect to the first fixed page — the one people write
  as "Sobre" — because a page about the author is something to write, not
  something to generate.

  The address stays because it is inside the `@id` of the `Person` in every
  article's structured data. That `@id` is an identifier and does not have to
  resolve, but one that redirects to a real page is worth more than one that
  404s, and every link already pointing here keeps working.
  """
  use BlogoWeb, :controller

  alias Blogo.Content

  def author(conn, %{"slug" => slug}) do
    with %{} <- Content.get_author_by_slug(slug),
         [page | _] <- Content.list_pages() do
      redirect(conn, to: ~p"/#{page.slug}")
    else
      _ -> conn |> put_status(:not_found) |> text(gettext("Not found"))
    end
  end
end
