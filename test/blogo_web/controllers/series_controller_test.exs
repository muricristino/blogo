defmodule BlogoWeb.SeriesControllerTest do
  use BlogoWeb.ConnCase

  alias Blogo.{Content, Fixtures}

  defp series_with(count) do
    {:ok, s} =
      Content.upsert_series(%{
        name: "Avaliar sem se enganar",
        slug: "avaliar-#{System.unique_integer([:positive])}",
        description: "Do conjunto de teste ao limiar."
      })

    author = Fixtures.author()

    for i <- 1..count do
      Fixtures.post(%{
        author: author,
        series_id: s.id,
        series_position: i,
        title: "Parte #{i}",
        slug: "parte-#{i}-#{System.unique_integer([:positive])}"
      })
    end

    s
  end

  test "lists the parts in order", %{conn: conn} do
    s = series_with(3)
    html = conn |> get(~p"/serie/#{s.slug}") |> html_response(200)

    assert html =~ "Avaliar sem se enganar"
    assert html =~ "3 partes"

    # Ordem importa: a série é o argumento de que existe uma.
    assert [p1, p2, p3] = [
             :binary.match(html, "Parte 1"),
             :binary.match(html, "Parte 2"),
             :binary.match(html, "Parte 3")
           ]

    assert elem(p1, 0) < elem(p2, 0)
    assert elem(p2, 0) < elem(p3, 0)
  end

  test "an unknown series is 404, not a blank page", %{conn: conn} do
    assert conn |> get(~p"/serie/nao-existe") |> response(404)
  end

  test "says how many parts, never how many were read", %{conn: conn} do
    s = series_with(2)
    html = conn |> get(~p"/serie/#{s.slug}") |> html_response(200)

    assert html =~ "2 partes"
    refute html =~ "lidos"
  end

  test "carries structured data marking the reading order", %{conn: conn} do
    s = series_with(2)
    html = conn |> get(~p"/serie/#{s.slug}") |> html_response(200)

    assert html =~ "ItemList"
    assert html =~ "ItemListOrderAscending"
  end

  test "is in the sitemap, which is what gets it indexed", %{conn: conn} do
    s = series_with(1)
    xml = conn |> get(~p"/sitemap.xml") |> response(200)

    assert xml =~ "/serie/#{s.slug}"
  end

  describe "the article page" do
    test "says where it sits and links the series", %{conn: conn} do
      s = series_with(3)
      [_, second, _] = Content.get_series_by_slug(s.slug).posts

      html = conn |> get(~p"/#{second.slug}") |> html_response(200)

      assert html =~ "Parte 2 de 3"
      assert html =~ "/serie/#{s.slug}"
    end

    # An unpublished part 2 would otherwise make part 3 announce itself as
    # "parte 3 de 2".
    test "counts only the published parts", %{conn: conn} do
      s = series_with(2)
      author = Fixtures.author()

      Fixtures.post(%{
        author: author,
        series_id: s.id,
        series_position: 3,
        status: "draft",
        hero: nil
      })

      [_, second] = Content.get_series_by_slug(s.slug).posts
      html = conn |> get(~p"/#{second.slug}") |> html_response(200)

      assert html =~ "Parte 2 de 2"
    end

    test "an article outside a series says nothing about one", %{conn: conn} do
      post = Fixtures.post()
      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      refute html =~ "serie-badge"
    end
  end

  describe "the index" do
    test "shows a series once it has a published part", %{conn: conn} do
      s = series_with(2)
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Séries"
      assert html =~ "Avaliar sem se enganar"
      assert html =~ "/serie/#{s.slug}"
    end

    # The section used to be three hand-written maps, so it could never be
    # empty; now it can, and an empty box would be worse than none.
    test "drops the section when there is no series", %{conn: conn} do
      Fixtures.post()
      html = conn |> get(~p"/") |> html_response(200)

      refute html =~ "serie-section"
    end
  end
end
