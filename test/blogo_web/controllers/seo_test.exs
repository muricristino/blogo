defmodule BlogoWeb.SEOTest do
  @moduledoc """
  The pieces a search engine and a feed reader actually consume.

  Each of these was a gap found by reading the rendered pages of the live site,
  so each test names what was missing rather than what the function returns.
  """
  use BlogoWeb.ConnCase

  alias Blogo.{Content, Fixtures}

  defp json_ld(html) do
    ~r|<script type="application/ld\+json">(.*?)</script>|s
    |> Regex.scan(html)
    |> Enum.map(fn [_, body] -> Jason.decode!(body) end)
  end

  describe "the article's structured data" do
    # The card was rendered and declared in Open Graph, but the Article never
    # said it had an image — which is where a search engine takes the figure
    # for a rich result.
    test "declares the card image", %{conn: conn} do
      post = Fixtures.post()
      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      [article] = json_ld(html) |> Enum.filter(&(&1["@type"] == "Article"))
      assert article["image"] =~ "/imagem/#{post.slug}.png"
    end

    test "counts the words, which a summariser uses to judge depth", %{conn: conn} do
      post = Fixtures.post()
      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      [article] = json_ld(html) |> Enum.filter(&(&1["@type"] == "Article"))
      assert is_integer(article["wordCount"])
    end

    # The series page listed its articles; the articles never said they
    # belonged to one. Half a link is not a link.
    test "says which series it is part of", %{conn: conn} do
      {:ok, series} =
        Content.upsert_series(%{slug: "uma-serie", name: "Uma série", description: "…"})

      post = Fixtures.post(%{series_id: series.id, series_position: 1})
      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      [article] = json_ld(html) |> Enum.filter(&(&1["@type"] == "Article"))
      assert article["isPartOf"]["name"] == "Uma série"
      assert article["isPartOf"]["@id"] =~ "/serie/uma-serie#series"
    end

    test "an article outside a series says nothing about one", %{conn: conn} do
      post = Fixtures.post()
      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      [article] = json_ld(html) |> Enum.filter(&(&1["@type"] == "Article"))
      refute Map.has_key?(article, "isPartOf")
    end
  end

  describe "the site's own name" do
    test "reaches og:site_name and the header", %{conn: conn} do
      {:ok, _} = Content.update_site(%{"name" => "Caderno de campo"})
      Fixtures.post()

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(property="og:site_name" content="Caderno de campo")
      assert html =~ "Caderno de campo"
      refute html =~ ">blogo<"
    end
  end
end
