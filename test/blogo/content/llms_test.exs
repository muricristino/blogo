defmodule Blogo.Content.LlmsTest do
  @moduledoc """
  Two properties matter here. The map has to come out of the database, so that
  renaming the site or publishing an article is enough — there is no file to
  remember. And the article's markdown has to stay the article: a document that
  gains a canonical line and loses a block would be a second, worse copy of the
  post.
  """
  use Blogo.DataCase, async: true

  alias Blogo.Content
  alias Blogo.Content.{Llms, Markdown}
  alias Blogo.Fixtures

  @base "https://exemplo.test"

  defp map(overrides \\ %{}) do
    defaults = %{
      site: Content.the_site(),
      author: Content.the_author(),
      posts: Content.list_published(),
      pages: Content.list_pages(),
      base_url: @base
    }

    Llms.llms_txt(Map.merge(defaults, overrides))
  end

  describe "the map of the site" do
    test "takes its name and its description from the database" do
      {:ok, _} =
        Content.update_site(%{"name" => "Caderno de campo", "description" => "Só o que eu meço."})

      Fixtures.post()

      body = map()

      assert body =~ "# Caderno de campo"
      assert body =~ "> Só o que eu meço."
    end

    test "a rename changes the file, because nothing is written by hand" do
      Fixtures.post()
      {:ok, _} = Content.update_site(%{"name" => "Primeiro nome"})
      antes = map()

      {:ok, _} = Content.update_site(%{"name" => "Segundo nome"})
      depois = map()

      assert antes =~ "# Primeiro nome"
      assert depois =~ "# Segundo nome"
      refute depois =~ "Primeiro nome"
    end

    test "an unnamed install falls back to its host rather than to an invented name" do
      Fixtures.post()
      refute map() =~ "# blogo"
      assert map() =~ "# #{URI.parse(BlogoWeb.Endpoint.url()).host}"
    end

    test "carries who signs it, with the profiles that prove it is the same person" do
      author =
        Fixtures.author(%{
          name: "Muri Cristino",
          headline: "Engenheiro de software",
          bio: "Escrevo sobre o que eu meço.",
          same_as: ["https://github.com/muri", "https://linkedin.com/in/muri"]
        })

      Fixtures.post(%{author: author})

      body = map(%{author: author})

      assert body =~ "Escrito por Muri Cristino, Engenheiro de software."
      assert body =~ "Escrevo sobre o que eu meço."
      assert body =~ "https://github.com/muri"
      assert body =~ "https://linkedin.com/in/muri"
    end

    # The list is the point of the file: a title alone says what exists, not
    # what reading it would settle.
    test "each article carries what it claims, not just its title" do
      Fixtures.post(%{
        title: "A conta que ninguém faz",
        slug: "a-conta",
        meta_description: "Trocar de classificador raramente paga.",
        topics: ["custo", "avaliação"],
        reading_minutes: 9
      })

      body = map()

      assert body =~
               "- [A conta que ninguém faz](#{@base}/a-conta.md): " <>
                 "Trocar de classificador raramente paga."

      assert body =~ "9 min de leitura"
      assert body =~ "marcadores: custo, avaliação"
    end

    test "falls back to the subtitle when there is no search description" do
      Fixtures.post(%{
        title: "Sem busca",
        slug: "sem-busca",
        meta_description: nil,
        subtitle: "O que o resumo diria."
      })

      assert map() =~ "O que o resumo diria."
    end

    test "says in which order to read" do
      Fixtures.post()
      assert map() =~ "Do mais recente para o mais antigo"
    end

    test "a draft is not in the map" do
      Fixtures.post(%{status: "draft", title: "Rascunho secreto", slug: "rascunho-secreto"})

      refute map() =~ "Rascunho secreto"
      refute map() =~ "rascunho-secreto"
    end

    test "a fixed page is listed apart from the articles" do
      Fixtures.post(%{kind: "pagina", title: "Sobre", slug: "sobre"})

      body = map()

      assert body =~ "## Páginas"
      assert body =~ "- [Sobre](#{@base}/sobre.md)"
    end

    test "with no page at all there is no empty section" do
      Fixtures.post()
      refute map() =~ "## Páginas"
    end

    test "a site with nothing published says so instead of listing nothing" do
      assert map() =~ "Nenhum artigo publicado ainda."
    end

    test "tells the consumer where the markdown is and what to cite" do
      Fixtures.post()
      body = map()

      assert body =~ "`.md` no fim"
      assert body =~ "O endereço para citar é sempre o HTML"
    end

    test "states this install's answer about AI crawlers" do
      Fixtures.post()
      {:ok, _} = Content.update_site(%{"ai_crawlers" => "citation"})

      assert map(%{site: Content.the_site()}) =~ "Treinar: não permitido"
    end
  end

  describe "the article as markdown" do
    test "is the same document the editor writes, plus what a consumer needs" do
      post = Fixtures.post(%{slug: "um-artigo", title: "Um artigo"})

      document = Llms.document(post, @base)

      assert document =~ "canonical: #{@base}/um-artigo"
      assert document =~ "autor: #{post.author.name}"
      assert document =~ "publicado: #{DateTime.to_date(post.published_at)}"
      assert document =~ "titulo: Um artigo"
    end

    # The extra lines are keys the dialect does not know, and it has to keep
    # ignoring them: the round trip is what makes serving this text free.
    test "still parses back into exactly the blocks it came from" do
      blocks = [
        %{"type" => "section", "title" => "O que foi medido"},
        %{"type" => "text", "paragraphs" => ["Uma medição.", "Outra."]},
        %{"type" => "question", "text" => "Em que tamanho isso deixa de valer?"},
        %{
          "type" => "source",
          "title" => "Medições próprias",
          "url" => "https://exemplo.test/dados",
          "note" => "Mediana de 40 chamadas."
        }
      ]

      post = Fixtures.post(%{body: %{"blocks" => blocks}})

      {:ok, parsed} = Markdown.from_markdown(Llms.document(post, @base))

      assert parsed.body["blocks"] == blocks
      assert parsed.title == post.title
      assert parsed.slug == post.slug
    end

    test "carries the body, not only the front matter" do
      post =
        Fixtures.post(%{
          body: %{"blocks" => [%{"type" => "text", "paragraphs" => ["O número era 0,956."]}]}
        })

      assert Llms.document(post, @base) =~ "O número era 0,956."
    end
  end
end
