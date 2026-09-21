alias Blogo.Content

author = Content.get_author_by_slug("muri-cristino")

texto = fn paras -> %{"type" => "text", "paragraphs" => paras} end

outros = [
  %{
    title: "Fail-open: quando a falha total vira silêncio",
    subtitle:
      "Um `return false` defensivo antes da linha de log transformou 404 em “tudo é humano” por três meses. O padrão, e como detectá-lo.",
    slug: "fail-open",
    topics: ["produção", "observabilidade"],
    minutes: 9,
    days: 7,
    blocks: [
      texto.([
        "O classificador chamava um modelo que tinha sido descontinuado. Recebia 404, caía num `return false` defensivo e classificava tudo como humano.",
        "O `catch` era uma decisão defensável: melhor deixar passar que silenciar cliente de verdade. Mas ele também transformou falha total em algo invisível, porque o retorno acontecia antes da linha que logava."
      ]),
      %{
        "type" => "callout",
        "variant" => "bad",
        "title" => "O teste que ninguém escreve",
        "text" =>
          "Todo fail-open precisa de um contador. Se o caminho de erro não incrementa nada, " <>
            "ele não tem como te avisar que virou o caminho principal."
      }
    ]
  },
  %{
    title: "Como eu monto um conjunto de 180 casos",
    subtitle:
      "Negativo difícil não é o que é difícil pro modelo — é o que aparece na mesma consulta. Um método em quatro passos, com a planilha.",
    slug: "conjunto-de-180-casos",
    topics: ["avaliação", "método"],
    minutes: 14,
    days: 14,
    blocks: [
      texto.([
        "Oito exemplos escolhidos de cabeça me deram “separação perfeita”. Os mesmos 180 casos, com negativos difíceis, deram AUC 0,508 — o que uma moeda entrega.",
        "A diferença inteira estava em quem eu deixei entrar no conjunto."
      ]),
      %{
        "type" => "callout",
        "variant" => "warn",
        "title" => "A regra vem antes",
        "text" =>
          "Escreva o critério do rótulo numa frase antes de rodar qualquer coisa. " <>
            "Sem isso você racionaliza o rótulo olhando a saída, e nem percebe que fez."
      }
    ]
  },
  %{
    title: "McNemar em vinte linhas de Ruby",
    subtitle:
      "Comparar duas acurácias soltas desperdiça a informação mais útil que você tem: os dois modelos viram os mesmos itens.",
    slug: "mcnemar-em-ruby",
    topics: ["avaliação", "rails"],
    minutes: 6,
    days: 23,
    blocks: [
      texto.([
        "Se os dois candidatos foram avaliados nos mesmos casos, comparar as acurácias joga fora o pareamento. McNemar olha só os casos em que eles discordam, que é onde a informação está."
      ]),
      %{
        "type" => "code",
        "lang" => "ruby",
        "source" =>
          "b = pairs.count { |a, c| a && !c }   # só o A acerta\n" <>
            "c = pairs.count { |a, cc| cc && !a } # só o B acerta\n" <>
            "m = b + c\n" <>
            "p_value = 2 * (0..[b, c].min).sum { |i| binom(m, i) } / 2.0**m",
        "caption" => "Com b + c pequeno, use a forma exata; a aproximação de qui-quadrado mente."
      }
    ]
  },
  %{
    title: "O índice que o Postgres decidiu não usar",
    subtitle:
      "Uma noite lendo `EXPLAIN ANALYZE` pra descobrir que a estatística estava velha e o planner tinha razão.",
    slug: "indice-que-o-postgres-nao-usou",
    topics: ["postgres"],
    minutes: 11,
    days: 31,
    blocks: [
      texto.([
        "O índice existia, a query filtrava exatamente por ele, e o planner insistia num seq scan. A tentação é forçar com `enable_seqscan = off` e seguir a vida.",
        "O `ANALYZE` resolveu em um segundo. A tabela tinha crescido 40x desde a última coleta de estatística, e o planner estava estimando com números de outro mundo."
      ])
    ]
  },
  %{
    title: "Nota: três perguntas antes de trocar de fornecedor",
    subtitle: "Uma nota curta. A terceira é a única que importa, e quase ninguém faz.",
    slug: "tres-perguntas-antes-de-trocar",
    kind: "nota",
    topics: ["notas curtas"],
    minutes: 3,
    days: 40,
    blocks: [
      texto.([
        "**Um.** O que existe hoje é ruim, ou está quebrado? São coisas diferentes, e a segunda se conserta de graça.",
        "**Dois.** O ganho medido cobre o custo de mais uma dependência?",
        "**Três.** Se o fornecedor novo sumir em seis meses, o que acontece com você?"
      ])
    ]
  }
]

for o <- outros do
  {:ok, _} =
    Content.upsert_post(%{
      title: o.title,
      subtitle: o.subtitle,
      slug: o.slug,
      kind: Map.get(o, :kind, "ensaio"),
      status: "published",
      published_at: DateTime.utc_now() |> DateTime.add(-o.days * 86_400) |> DateTime.truncate(:second),
      reading_minutes: o.minutes,
      topics: o.topics,
      meta_description: o.subtitle,
      body: %{"blocks" => o.blocks},
      author_id: author.id
    })
end

IO.puts("+#{length(outros)} artigos")
