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
        kind: "artigo",
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

    test "carries the cover photograph by the image's name" do
      md = Markdown.to_markdown(%{title: "x", cover: "prints/fundo.png", body: %{"blocks" => []}})
      assert md =~ "capa: prints/fundo.png"
      assert {:ok, %{cover: "prints/fundo.png"}} = Markdown.from_markdown(md)
    end

    test "an empty cover line clears it" do
      assert {:ok, %{cover: ""}} = Markdown.from_markdown("---\ntitulo: x\ncapa:\n---\n")
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
      tipo: artigo
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

      ![A rua à noite, com a neblina do PS1](prints/rua.png)
      + A neblina esconde o fim do mapa.

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

  describe "a text block that is more than one paragraph" do
    test "keeps its note, caption and drop cap on the whole block" do
      block = %{
        "type" => "text",
        "drop" => true,
        "note" => "Sobre os números.",
        "paragraphs" => ["Primeiro.", "Segundo."]
      }

      assert [^block] = roundtrip([block])
    end

    test "without attachments stays plain markdown" do
      md =
        Markdown.to_markdown(%{
          body: %{"blocks" => [%{"type" => "text", "paragraphs" => ["Um.", "Dois."]}]}
        })

      refute md =~ ":::"
    end

    test "a code block saved under the old key keeps its source" do
      assert [%{"source" => "puts 1"}] =
               roundtrip([%{"type" => "code", "lang" => "ruby", "code" => "puts 1"}])
    end
  end

  describe "key numbers" do
    test "keep which one is highlighted, because the summary card draws it" do
      block = %{
        "type" => "keynumbers",
        "items" => [
          %{"value" => "0,956", "label" => "AUC", "accent" => true},
          %{"value" => "0,508", "label" => "AUC do outro"}
        ]
      }

      assert [^block] = roundtrip([block])
    end
  end

  describe "image" do
    test "keeps its name, its alt text and its caption" do
      image = %{
        "type" => "image",
        "src" => "prints/rua.png",
        "alt" => "A rua à noite",
        "caption" => "A neblina esconde o fim do mapa."
      }

      assert [^image] = roundtrip([image])
    end

    test "is written as standard markdown on a line of its own" do
      md =
        Markdown.to_markdown(%{
          body: %{"blocks" => [%{"type" => "image", "src" => "a.png", "alt" => "Uma tela"}]}
        })

      assert md =~ "![Uma tela](a.png)"
    end

    test "without alt text does not invent one" do
      assert [block] = roundtrip([%{"type" => "image", "src" => "a.png"}])
      refute Map.has_key?(block, "alt")
    end

    test "an alt text with brackets survives" do
      image = %{"type" => "image", "src" => "a.png", "alt" => "O menu [pausa] aberto"}
      assert [^image] = roundtrip([image])
    end

    test "inside a paragraph stays text, because only a line of its own is a block" do
      assert [%{"type" => "text"}] =
               roundtrip([%{"type" => "text", "paragraphs" => ["Veja ![x](a.png) aqui."]}])
    end

    test "image_url rewrites the name into an address and nothing else" do
      post = %{body: %{"blocks" => [%{"type" => "image", "src" => "a.png", "alt" => "x"}]}}
      md = Markdown.to_markdown(post, image_url: &("https://exemplo.com/midia/" <> &1))
      assert md =~ "![x](https://exemplo.com/midia/a.png)"
    end
  end

  describe "a document with every block" do
    test "the text written for a post parses back to exactly the same text" do
      post = %{
        title: "Jogo da Paulista",
        subtitle: "Uma noite, um jogo.",
        slug: "jogo-da-paulista",
        kind: "artigo",
        topics: ["godot", "claude code"],
        meta_description: "Como foi.",
        body: %{"blocks" => every_block()}
      }

      md = Markdown.to_markdown(post)
      assert stable?(md) == md
    end

    test "survives the round trip with every type intact" do
      blocks = every_block()

      assert Enum.map(blocks, & &1["type"]) |> Enum.uniq() |> length() ==
               length(Markdown.palette())

      assert roundtrip(blocks) == blocks
    end

    test "the drop cap survives, because it is an editorial choice" do
      assert [%{"drop" => true, "paragraphs" => ["Abertura."]}] =
               roundtrip([%{"type" => "text", "paragraphs" => ["Abertura."], "drop" => true}])
    end
  end

  describe "list" do
    test "a numbered list is written one item per line" do
      md =
        Markdown.to_markdown(%{
          body: %{"blocks" => [%{"type" => "list", "ordered" => true, "items" => ["um", "dois"]}]}
        })

      assert md =~ "1. um\n2. dois"
    end

    test "lines that start with a marker become a list, not a run-on paragraph" do
      {:ok, attrs} =
        Markdown.from_markdown("Em ordem:\n\n1. o calçadão;\n2. a rua;\n3. os casarões.\n")

      assert [
               %{"type" => "text", "paragraphs" => ["Em ordem:"]},
               %{
                 "type" => "list",
                 "ordered" => true,
                 "items" => ["o calçadão;", "a rua;", "os casarões."]
               }
             ] = attrs.body["blocks"]
    end

    test "a bulleted list may start right under a paragraph" do
      {:ok, attrs} =
        Markdown.from_markdown("Três defeitos:\n- o vértice treme;\n- a textura entorta.\n")

      assert [
               %{"type" => "text", "paragraphs" => ["Três defeitos:"]},
               %{
                 "type" => "list",
                 "ordered" => false,
                 "items" => ["o vértice treme;", "a textura entorta."]
               }
             ] = attrs.body["blocks"]
    end

    test "an indented line continues the item above it" do
      {:ok, attrs} = Markdown.from_markdown("- um item\n  que continua\n- outro\n")
      assert [%{"items" => ["um item que continua", "outro"]}] = attrs.body["blocks"]
    end

    test "a numbered list that does not start at one keeps where it starts" do
      block = %{"type" => "list", "ordered" => true, "start" => 4, "items" => ["quatro", "cinco"]}
      assert [^block] = roundtrip([block])
    end

    test "keeps bold, italic and links inside items" do
      block = %{
        "type" => "list",
        "ordered" => false,
        "items" => ["**Laboratórios.** Uma cena por parte, no [Godot](https://godotengine.org)."]
      }

      assert [^block] = roundtrip([block])
    end

    test "a paragraph that opens like a list item stays a paragraph" do
      for p <- [
            "- não é lista, é um travessão de diálogo.",
            "1984. Foi o ano.",
            "1. Isto era um parágrafo."
          ] do
        assert [%{"type" => "text", "paragraphs" => [^p]}] =
                 roundtrip([%{"type" => "text", "paragraphs" => [p]}])
      end
    end

    test "a numbered line in the middle of a sentence does not break the paragraph" do
      {:ok, attrs} = Markdown.from_markdown("Nasceu em\n1984. E depois.\n")

      assert [%{"type" => "text", "paragraphs" => ["Nasceu em 1984. E depois."]}] =
               attrs.body["blocks"]
    end
  end

  describe "links in running text" do
    test "survive the round trip in every block that holds prose" do
      link = "Os prédios vieram do [OpenStreetMap](https://www.openstreetmap.org/copyright)."

      blocks = [
        %{
          "type" => "text",
          "paragraphs" => [link],
          "note" => "Dado do [GeoSampa](https://geosampa.prefeitura.sp.gov.br)."
        },
        %{"type" => "callout", "variant" => "note", "text" => link},
        %{"type" => "quote", "text" => link},
        %{"type" => "image", "src" => "a.png", "caption" => link}
      ]

      assert roundtrip(blocks) == blocks
    end
  end

  describe "source" do
    test "writes its description once, inside the fence" do
      md =
        Markdown.to_markdown(%{
          body: %{
            "blocks" => [
              %{
                "type" => "source",
                "url" => "https://exemplo.com",
                "title" => "Skill",
                "note" => "Passo a passo."
              }
            ]
          }
        })

      assert md =~ ":::origem https://exemplo.com\nSkill\nPasso a passo.\n:::"
      refute md =~ "^ "
    end

    test "a file saved with the description repeated as a note reads back as one source" do
      {:ok, attrs} =
        Markdown.from_markdown(
          ":::origem https://exemplo.com\nSkill\nPasso a passo.\n:::\n^ Passo a passo.\n"
        )

      assert [%{"type" => "source", "note" => "Passo a passo."}] = attrs.body["blocks"]
    end
  end

  defp every_block do
    [
      %{"type" => "text", "paragraphs" => ["Abertura."], "drop" => true},
      %{"type" => "section", "n" => "01", "title" => "Uma seção"},
      %{
        "type" => "list",
        "ordered" => true,
        "items" => ["Um [link](https://exemplo.com).", "Dois."]
      },
      %{"type" => "text", "paragraphs" => ["Com nota."], "note" => "A nota."},
      %{
        "type" => "list",
        "ordered" => false,
        "items" => ["Solto.", "Outro."],
        "note" => "Uma nota."
      },
      %{"type" => "text", "paragraphs" => ["Dois", "parágrafos."], "caption" => "Juntos."},
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
      %{
        "type" => "keynumbers",
        "items" => [
          %{"value" => "42", "label" => "casos"},
          %{"value" => "0,956", "label" => "AUC", "accent" => true}
        ]
      },
      %{"type" => "question", "text" => "E depois?"},
      %{"type" => "source", "title" => "Uma fonte", "url" => "https://exemplo.com"},
      %{
        "type" => "source",
        "title" => "Outra fonte",
        "url" => "https://exemplo.com/b",
        "note" => "Com descrição."
      },
      %{
        "type" => "image",
        "src" => "prints/rua.png",
        "alt" => "A rua",
        "caption" => "A neblina."
      },
      %{"type" => "marginnote", "text" => "Sozinha na margem."}
    ]
  end
end
