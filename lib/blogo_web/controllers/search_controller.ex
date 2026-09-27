defmodule BlogoWeb.SearchController do
  @moduledoc """
  Finding an article by what it says.

  A plain GET, so a search is an address: it can be shared, bookmarked and gone
  back to. `noindex` because a results page is not content — it is a view of
  content that already has its own addresses.
  """
  use BlogoWeb, :controller

  alias Blogo.Content

  def show(conn, params) do
    query = params |> Map.get("q", "") |> to_string() |> String.slice(0, 200)
    results = Content.search(query)

    conn
    # `preview?` is what puts `noindex` in the head. A results page is a view of
    # content that already has its own addresses; indexing it competes with them.
    |> assign(:preview?, true)
    |> assign(:current_author, Content.the_author())
    |> assign(:nav, :busca)
    |> assign(:page_title, page_title(query))
    |> render(:show, query: query, results: results)
  end

  defp page_title(""), do: gettext("Search")
  defp page_title(query), do: gettext("Search: %{query}", query: query)
end
