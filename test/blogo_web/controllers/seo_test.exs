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
  end

  describe "where the article says its numbers came from" do
    test "the source blocks become citations", %{conn: conn} do
      post =
        Fixtures.post(%{
          body: %{
            "blocks" => [
              %{"type" => "text", "paragraphs" => ["A mediana ficou em 0,956."]},
              %{
                "type" => "source",
                "title" => "Medições próprias, setembro de 2026",
                "url" => "https://exemplo.test/dados",
                "note" => "Mediana de 40 chamadas pareadas."
              }
            ]
          }
        })

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)
      [article] = json_ld(html) |> Enum.filter(&(&1["@type"] == "Article"))

      assert article["citation"] == [
               %{
                 "@type" => "CreativeWork",
                 "name" => "Medições próprias, setembro de 2026",
                 "url" => "https://exemplo.test/dados",
                 "description" => "Mediana de 40 chamadas pareadas."
               }
             ]
    end

    test "a source without a link still says where the numbers came from", %{conn: conn} do
      post =
        Fixtures.post(%{
          body: %{
            "blocks" => [
              %{
                "type" => "source",
                "title" => "Medições próprias",
                "note" => "Rodadas, não estimadas."
              }
            ]
          }
        })

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)
      [article] = json_ld(html) |> Enum.filter(&(&1["@type"] == "Article"))

      assert [%{"name" => "Medições próprias"}] = article["citation"]
    end

    # An empty key is a claim about having sources, made by an article that has
    # none.
    test "an article with no source block has no citation key at all", %{conn: conn} do
      post = Fixtures.post()

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)
      [article] = json_ld(html) |> Enum.filter(&(&1["@type"] == "Article"))

      refute Map.has_key?(article, "citation")
    end

    # "Pergunta guardada" is the question the article leaves open — there is no
    # acceptedAnswer to emit, and promoting the next paragraph into one would be
    # structured data contradicting the page.
    test "a question block does not become a FAQPage", %{conn: conn} do
      post =
        Fixtures.post(%{
          body: %{
            "blocks" => [
              %{"type" => "question", "text" => "Em que tamanho de lista isso deixa de valer?"},
              %{"type" => "text", "paragraphs" => ["Não medi."]}
            ]
          }
        })

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      refute html =~ "FAQPage"
      refute html =~ "acceptedAnswer"
      # The question is still on the page for a reader, and in the markdown.
      assert html =~ "Em que tamanho de lista isso deixa de valer?"
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
