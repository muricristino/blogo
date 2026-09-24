defmodule BlogoWeb.GeoTest do
  @moduledoc """
  What the site hands something that is not a browser: the article in markdown,
  and the map at `/llms.txt` that lists every one of them.
  """
  use BlogoWeb.ConnCase, async: true

  alias Blogo.Content
  alias Blogo.Fixtures

  defp base, do: BlogoWeb.Endpoint.url()

  describe "the article in markdown" do
    test "serves the text of the article, as markdown", %{conn: conn} do
      post =
        Fixtures.post(%{
          slug: "a-conta",
          title: "A conta que ninguém faz",
          body: %{
            "blocks" => [
              %{"type" => "section", "title" => "O que foi medido"},
              %{"type" => "text", "paragraphs" => ["A mediana ficou em 0,956."]}
            ]
          }
        })

      conn = get(conn, "/#{post.slug}.md")
      body = response(conn, 200)

      assert response_content_type(conn, :md) =~ "text/markdown"
      assert body =~ "titulo: A conta que ninguém faz"
      assert body =~ "## O que foi medido"
      assert body =~ "A mediana ficou em 0,956."
      # The HTML shell has no business here: this is the document, not a page.
      refute body =~ "<html"
    end

    # The markdown is a second representation of one article. Saying so is what
    # keeps a search engine from treating it as a duplicate page.
    test "points its canonical at the HTML, in the header a text file can carry", %{conn: conn} do
      post = Fixtures.post(%{slug: "a-conta"})

      conn = get(conn, "/#{post.slug}.md")

      assert get_resp_header(conn, "link") == [~s(<#{base()}/a-conta>; rel="canonical")]
    end

    # `:accepts` in the browser pipeline speaks HTML, and it runs after this.
    test "answers a client that asks for markdown and nothing else", %{conn: conn} do
      post = Fixtures.post()

      body =
        conn
        |> put_req_header("accept", "text/markdown")
        |> get("/#{post.slug}.md")
        |> response(200)

      assert body =~ "titulo:"
    end

    test "a fixed page has one too", %{conn: conn} do
      page = Fixtures.post(%{kind: "pagina", slug: "sobre", title: "Sobre"})

      assert conn |> get("/#{page.slug}.md") |> response(200) =~ "titulo: Sobre"
    end

    test "a draft has none", %{conn: conn} do
      post = Fixtures.post(%{status: "draft", slug: "rascunho-x"})

      assert conn |> get("/#{post.slug}.md") |> response(404)
    end

    test "an address that belongs to nothing is still a 404", %{conn: conn} do
      assert conn |> get("/nada-aqui.md") |> response(404)
    end

    test "the HTML page says where its markdown is", %{conn: conn} do
      post = Fixtures.post(%{slug: "a-conta"})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ ~s(rel="alternate" type="text/markdown" href="#{base()}/a-conta.md")
      assert html =~ ~s(<link rel="canonical" href="#{base()}/a-conta">)
    end

    test "the HTML article is still HTML", %{conn: conn} do
      post = Fixtures.post()

      assert conn |> get(~p"/#{post.slug}") |> html_response(200) =~ "<html"
    end
  end

  describe "llms.txt" do
    test "is built from the site, the author and what is published", %{conn: conn} do
      {:ok, _} =
        Content.update_site(%{"name" => "Caderno de campo", "description" => "Só o que eu meço."})

      Fixtures.post(%{
        title: "A conta que ninguém faz",
        slug: "a-conta",
        meta_description: "Trocar de classificador raramente paga."
      })

      conn = get(conn, ~p"/llms.txt")
      body = response(conn, 200)

      assert response_content_type(conn, :txt) =~ "text/plain"
      assert body =~ "# Caderno de campo"
      assert body =~ "> Só o que eu meço."
      assert body =~ "- [A conta que ninguém faz](#{base()}/a-conta.md): "
      assert body =~ "Trocar de classificador raramente paga."
      assert body =~ "#{base()}/feed.xml"
    end

    test "an article published after it was first read is in it", %{conn: conn} do
      refute conn |> get(~p"/llms.txt") |> response(200) =~ "Artigo novo"

      Fixtures.post(%{title: "Artigo novo", slug: "artigo-novo"})

      assert conn |> get(~p"/llms.txt") |> response(200) =~ "Artigo novo"
    end

    # A map written for models next to a robots.txt refusing every model would
    # be the same decision answered twice, differently.
    test "is gone when the install refuses AI crawlers altogether", %{conn: conn} do
      Fixtures.post()
      {:ok, _} = Content.update_site(%{"ai_crawlers" => "none"})

      assert conn |> get(~p"/llms.txt") |> response(404)
    end
  end
end
