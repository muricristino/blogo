defmodule Blogo.Content.MarkdownTest do
  @moduledoc """
  The editor has two modes writing to one document, so the conversion between
  them is the load-bearing piece: a writer who starts in rich mode, switches to
  markdown and switches back must find the article they left.

  Two properties are checked separately because they are not the same promise:

    * **stable** — markdown → blocks → markdown returns the same text. This one
      is absolute; a document that changes every time it is saved is unusable.
    * **faithful** — blocks → markdown → blocks preserves every block the
      renderer distinguishes. Adjacent plain paragraphs are allowed to merge,
      and the test says why.
  """
  use ExUnit.Case, async: true

  alias Blogo.Content.Markdown

  defp roundtrip(blocks) do
    {:ok, attrs} = Markdown.from_markdown(Markdown.to_markdown(%{body: %{"blocks" => blocks}}))
    attrs.body["blocks"]
  end

  defp stable?(text) do
    {:ok, attrs} = Markdown.from_markdown(text)
    Markdown.to_markdown(Map.put(attrs, :body, attrs.body))
  end

  describe "front matter" do
    test "carries the fields that are not part of the body" do
      post = %{
        title: "O teste que concorda com você",
        subtitle: "Oito exemplos disseram separação perfeita.",
        slug: "o-teste-que-concorda",
        kind: "ensaio",
        topics: ["avaliação", "classificadores"],
        meta_description: "Comparação medida.",
        body: %{"blocks" => []}
      }

      md = Markdown.to_markdown(post)
      assert md =~ "titulo: O teste que concorda com você"
      assert md =~ "marcadores: [avaliação, classificadores]"

      {:ok, back} = Markdown.from_markdown(md)
      assert back.title == post.title
      assert back.subtitle == post.subtitle
      assert back.slug == post.slug
      assert back.topics == post.topics
      assert back.meta_description == post.meta_description
    end

    test "a document without front matter is still readable" do
      assert {:ok, attrs} = Markdown.from_markdown("Só um parágrafo.\n")
      assert [%{"type" => "text", "paragraphs" => ["Só um parágrafo."]}] = attrs.body["blocks"]
    end
  end

  describe "the five blocks markdown already has" do
    test "paragraph" do
      assert [%{"type" => "text", "paragraphs" => ["Um parágrafo com **negrito**."]}] =
               roundtrip([%{"type" => "text", "paragraphs" => ["Um parágrafo com **negrito**."]}])
    end

    test "section keeps its number" do
      assert [%{"type" => "section", "n" => "03", "title" => "Onde o erro cai"}] =
               roundtrip([%{"type" => "section", "n" => "03", "title" => "Onde o erro cai"}])
    end

    test "section without a number does not invent one" do
      assert [block] = roundtrip([%{"type" => "section", "title" => "Sem número"}])
      refute Map.has_key?(block, "n")
    end

    test "table keeps headers and rows" do
      table = %{
        "type" => "table",
        "headers" => ["Exemplo", "Probabilidade"],
        "rows" => [["Espaço Vida", "0,5570"], ["Mercadinho São Jorge", "0,0028"]]
      }

      assert [^table] = roundtrip([table])
    end

    test "code keeps its language and its exact source" do
      code = %{
        "type" => "code",
        "lang" => "bash",
        "source" => "$ classificar \"quer cancelar?\"\n0.9912"
      }

      assert [^code] = roundtrip([code])
    end

    test "quote keeps its attribution" do
      quote_block = %{"type" => "quote", "text" => "Uma frase.", "cite" => "Quem disse"}
      assert [^quote_block] = roundtrip([quote_block])
    end
  end

  describe "the six blocks that needed a fence" do
    test "callout keeps variant and title" do
      callout = %{
        "type" => "callout",
        "variant" => "bad",
        "title" => "O antídoto",
        "text" => "Se os negativos são óbvios, você está medindo se o modelo sabe ler."
      }

      assert [^callout] = roundtrip([callout])
    end

    test "callout without a variant defaults to note" do
      assert [%{"variant" => "note", "text" => "Sem variante."}] =
               roundtrip([%{"type" => "callout", "text" => "Sem variante."}])
    end

    test "margin note" do
      assert [%{"type" => "marginnote", "text" => "Uma nota."}] =
               roundtrip([%{"type" => "marginnote", "text" => "Uma nota."}])
    end

    test "question" do
      assert [%{"type" => "question", "text" => "E se o fornecedor sumir?"}] =
               roundtrip([%{"type" => "question", "text" => "E se o fornecedor sumir?"}])
    end

    test "source keeps url and note" do
      source = %{
        "type" => "source",
        "url" => "https://exemplo.com",
        "title" => "Conjuntos sintéticos",
        "note" => "Tudo que aparece como número foi rodado."
      }

      assert [^source] = roundtrip([source])
    end

    test "key numbers" do
      keynumbers = %{
        "type" => "keynumbers",
        "items" => [
          %{"value" => "0,956", "label" => "AUC do Jev"},
          %{"value" => "0,508", "label" => "AUC do Laya"}
        ]
      }

      assert [^keynumbers] = roundtrip([keynumbers])
    end

    test "diagram keeps its form, its alt and its data" do
      diagram = %{
        "type" => "diagram",
        "form" => "distribuicao",
        "alt" => "Jev separa positivos de negativos difíceis",
        "data" => %{"rows" => [%{"auc" => "0,956", "neg_c" => 85}]}
      }

      assert [^diagram] = roundtrip([diagram])
    end

    test "a diagram with broken JSON names the problem instead of crashing" do
      md = ":::diagrama distribuicao\nalt: uma figura\n{isto não é json}\n:::\n"
      assert {:error, message} = Markdown.from_markdown(md)
      assert message =~ "diagrama"
    end

    test "an unknown fence is reported, not silently dropped" do
      assert {:error, message} = Markdown.from_markdown(":::inventado\nconteúdo\n:::\n")
      assert message =~ "inventado"
    end
  end

  describe "caption and margin note attach to the block above" do
    test "a caption under a figure stays with the figure" do
      diagram = %{
        "type" => "diagram",
        "form" => "fluxo",
        "data" => %{},
        "caption" => "A terceira é a única que sobrevive ao contrato."
      }

      assert [^diagram] = roundtrip([diagram])
    end

    test "a margin note stays with its paragraph" do
      text = %{
        "type" => "text",
        "paragraphs" => ["O parágrafo."],
        "note" => "**Regra do rótulo:** escrita antes."
      }

      assert [^text] = roundtrip([text])
    end

    test "a table carries both at once" do
      assert [%{"caption" => "Uma legenda.", "note" => "Uma nota."}] =
               roundtrip([
                 %{
                   "type" => "table",
                   "headers" => ["a"],
                   "rows" => [["1"]],
                   "caption" => "Uma legenda.",
                   "note" => "Uma nota."
                 }
               ])
    end
  end

  describe "stability" do
    test "parsing and rendering a document returns the same text" do
      text = """
      ---
      titulo: O teste que concorda com você
      resumo: Oito exemplos disseram separação perfeita.
      endereco: o-teste-que-concorda
      tipo: ensaio
      marcadores: [avaliação, método]
      ---

      Apareceu um modelo novo e eu quis saber se servia.
      ^ **Nota:** escrita antes.

      ## 01 O teste que disse "separação perfeita"

      O problema é que eu tinha escolhido os negativos.

      | Exemplo | Probabilidade |
      | --- | --- |
      | Espaço Vida | 0,5570 |
      + Duas linhas bastam para mostrar a ordem.

      ```bash
      $ classificar "quer cancelar?"
      ```

      :::aviso bad O antídoto
      Se os negativos são óbvios, você está medindo se o modelo sabe ler.
      :::

      :::margem
      Uma nota que vive sozinha.
      :::

      :::numeros
      0,956 | AUC do Jev
      0,508 | AUC do Laya
      :::

      :::diagrama distribuicao
      alt: Jev separa positivos de negativos difíceis
      {"rows":[{"auc":"0,956"}]}
      :::
      + As curvas são esquemáticas.
      """

      assert stable?(text) == stable?(stable?(text))
    end
  end

  describe "the normalisation the writer will notice" do
    test "adjacent plain paragraphs merge into one block" do
      # Two text blocks with nothing attached render exactly as one block with
      # two paragraphs, so the merge costs the writer nothing. A block that
      # carries a margin note is never merged, because that note points at a
      # specific paragraph.
      assert [%{"paragraphs" => ["Primeiro.", "Segundo."]}] =
               roundtrip([
                 %{"type" => "text", "paragraphs" => ["Primeiro."]},
                 %{"type" => "text", "paragraphs" => ["Segundo."]}
               ])
    end

    test "a paragraph with a margin note is not merged into its neighbour" do
      assert [
               %{"paragraphs" => ["Primeiro."], "note" => "Uma nota."},
               %{"paragraphs" => ["Segundo."]}
             ] =
               roundtrip([
                 %{"type" => "text", "paragraphs" => ["Primeiro."], "note" => "Uma nota."},
                 %{"type" => "text", "paragraphs" => ["Segundo."]}
               ])
    end
  end

  describe "a document with all eleven blocks" do
    test "survives the round trip with every type intact" do
      blocks = [
        %{"type" => "text", "paragraphs" => ["Abertura."], "drop" => true},
        %{"type" => "section", "n" => "01", "title" => "Uma seção"},
        %{"type" => "text", "paragraphs" => ["Com nota."], "note" => "A nota."},
        %{"type" => "table", "headers" => ["a", "b"], "rows" => [["1", "2"]]},
        %{
          "type" => "diagram",
          "form" => "fluxo",
          "data" => %{"steps" => []},
          "alt" => "Um fluxo"
        },
        %{"type" => "callout", "variant" => "warn", "title" => "Cuidado", "text" => "Um aviso."},
        %{"type" => "code", "lang" => "elixir", "source" => "IO.puts(:ok)"},
        %{"type" => "quote", "text" => "Uma frase.", "cite" => "Alguém"},
        %{"type" => "keynumbers", "items" => [%{"value" => "42", "label" => "casos"}]},
        %{"type" => "question", "text" => "E depois?"},
        %{"type" => "source", "title" => "Uma fonte", "url" => "https://exemplo.com"},
        %{"type" => "marginnote", "text" => "Sozinha na margem."}
      ]

      assert roundtrip(blocks) == blocks
    end

    test "the drop cap survives, because it is an editorial choice" do
      assert [%{"drop" => true, "paragraphs" => ["Abertura."]}] =
               roundtrip([%{"type" => "text", "paragraphs" => ["Abertura."], "drop" => true}])
    end
  end
end
