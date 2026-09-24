defmodule BlogoWeb.SeriesController do
  @moduledoc """
  A series has a page of its own because that is what makes it worth anything
  to a reader arriving from search: one address that holds the reading order
  and links every part. Without it a series is a decoration on the index.
  """
  use BlogoWeb, :controller

  alias Blogo.Content
  alias BlogoWeb.SEO

  def show(conn, %{"slug" => slug}) do
    case Content.get_series_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> text("Não encontrada")

      series ->
        base = BlogoWeb.Endpoint.url()
        author = series.posts |> List.first() |> then(&(&1 && &1.author))

        conn
        |> assign(:current_author, author)
        |> assign(:nav, :artigos)
        |> assign(:seo, %{
          conn: conn,
          title: "#{series.name} · série",
          description: series.description,
          canonical: "#{base}/serie/#{series.slug}",
          image: first_card(series, base),
          json_ld: SEO.series(series, base)
        })
        |> render(:show, series: series)
    end
  end

  # The series has no figure of its own, so it borrows the one from the article
  # it starts with — which is the figure someone sharing the series would most
  # likely expect to see.
  defp first_card(%{posts: [first | _]}, base), do: "#{base}/imagem/#{first.slug}.png"
  defp first_card(_series, _base), do: nil
end
