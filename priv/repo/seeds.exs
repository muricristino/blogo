alias Blogo.Content

{:ok, author} =
  Content.upsert_author(%{
    name: "Muri Cristino",
    slug: "muri-cristino",
    headline: "Engenheiro de software",
    bio:
      "Escrevo sobre o que eu meço. Elixir, Rails, Postgres e a parte chata " <>
        "de avaliar modelo antes de colocar em produção.",
    city: "São Paulo",
    same_as: [
      "https://github.com/murichristopher",
      "https://www.linkedin.com/in/muricristino"
    ]
  })

blocks = [
  %{
    "type" => "text",
    "drop" => true,
    "paragraphs" => [
      "Dois modelos prometem a mesma coisa: em vez de gerar texto, devolver uma decisão tipada com probabilidade. O **Jev**, da TypeSafe, é API fechada em beta. O **Laya** é peso aberto sob Apache-2.0, e roda no seu Mac.",
      "Passei uma noite medindo os dois nos mesmos casos. A diferença não é de grau."
    ],
    "note" =>
      "**Sobre os números.** Conjuntos sintéticos, construídos por mim. Tudo que aparece " <>
        "aqui foi rodado, não estimado."
  },
  %{
    "type" => "keynumbers",
    "items" => [
      %{"value" => "0,956", "label" => "AUC do Jev contra negativos difíceis", "accent" => true},
      %{"value" => "0,508", "label" => "AUC do Laya nos mesmos casos"},
      %{"value" => "1,70x", "label" => "Jev mais rápido, mediana de 40 pares pareados"}
    ],
    "note" =>
      "Mesmos casos, mesmas perguntas, medidos na mesma noite. O que separa os dois " <>
        "não é acurácia de ponta: é negação, magnitude numérica e contagem."
  },
  %{
    "type" => "section",
    "n" => "01",
    "title" => "O que cada um faz"
  },
  %{
    "type" => "text",
    "paragraphs" => [
      "Os dois expõem a mesma API: você manda um estado e perguntas tipadas, e recebe probabilidades. Três tipos de pergunta, com os mesmos nomes nos dois — `noul` para sim ou não, `choice` para escolher uma opção, `score` para níveis ordenados.",
      "O Laya deixa a arquitetura à vista: é um encoder bidirecional da família BERT (`ModernBERT-large` no checkpoint em inglês, `mmBERT-base` no multilíngue) com cabeças de decisão em cima. 421 e 322 milhões de parâmetros. A TypeSafe não publica nada equivalente sobre o Jev."
    ]
  },
  %{
    "type" => "table",
    "headers" => ["", "Jev 1.13", "Laya multilíngue"],
    "rows" => [
      ["Onde roda", "API da TypeSafe", "seu hardware, via MLX"],
      ["Licença", "beta, sem termos publicados", "Apache-2.0"],
      ["Parâmetros", "não divulgado", "322M"],
      ["Janela de contexto", "32.000 tokens", "1.024 tokens"],
      ["Treinável nos seus dados", "não", "sim"],
      ["Custo por 1M de chamadas", "US$ 13,38", "zero, fora a energia"],
      ["Latência mediana", "295 ms", "26 ms"]
    ],
    "caption" =>
      "As duas últimas linhas medem coisas diferentes: uma inclui a rede, a outra não.",
    "note" => "**Janela.** 1.024 tokens parece pouco, mas nenhum caso meu passou de 400."
  },
  %{
    "type" => "section",
    "n" => "02",
    "title" => "O teste que separa os dois em trinta segundos"
  },
  %{
    "type" => "text",
    "paragraphs" => [
      "Antes de montar conjunto, rode negação. É uma linha e não precisa de rótulo nenhum."
    ]
  },
  %{
    "type" => "code",
    "lang" => "bash",
    "source" => """
    # pergunta: "a pessoa quer cancelar o serviço?"

    "quero cancelar minha assinatura"     laya 0,9912   jev 0,97
    "não quero cancelar, só uma dúvida"   laya 0,7123   jev 0,04
    "de jeito nenhum vou cancelar"        laya 0,9912   jev 0,05\
    """,
    "caption" => "No Laya, a frase que nega dá exatamente a mesma nota da que afirma.",
    "note" => "**Custa nada.** Seis chamadas, sem rótulo, e elimina a maioria dos candidatos."
  },
  %{
    "type" => "text",
    "paragraphs" => [
      "O Laya vê a palavra *cancelar* e decide. É assinatura de saco-de-palavras, e basta para descartá-lo como detector de intenção: “não me manda boleto” e “isso não é urgente” disparariam do mesmo jeito.",
      "O mesmo padrão aparece em contagem e em magnitude numérica. Com as mesmas palavras e só o número de itens mudando, o Laya responde “sim” para qualquer lista. E entre uma renda de R$ 900 e uma de R$ 60.000, ele não move nada."
    ]
  },
  %{
    "type" => "callout",
    "variant" => "warn",
    "title" => "A regra que explica os dois",
    "text" =>
      "O Laya responde bem a *esse texto afirma X?* e mal a *infira X a partir desse texto*. " <>
        "Sentimento funciona porque a frase expressa o sentimento. Negação, contagem e comparação " <>
        "numérica exigem compor, e é aí que ele para."
  },
  %{
    "type" => "section",
    "n" => "03",
    "title" => "No conjunto que importa"
  },
  %{
    "type" => "text",
    "paragraphs" => [
      "Montei 180 casos de qualificação de lead, com uma regra escrita antes de rodar qualquer coisa: positivo é quem presta atendimento de saúde a paciente humano com hora marcada.",
      "Metade dos negativos é **difícil** de propósito — farmácia, clínica veterinária, academia, estética, plano de saúde. Tudo que cheira a saúde sem se encaixar na regra. É essa a população que aparece numa busca real."
    ]
  },
  %{
    "type" => "diagram",
    "form" => "distribuicao",
    "alt" =>
      "Jev separa positivos de negativos difíceis com AUC 0,956; no Laya os dois grupos se sobrepõem, com AUC 0,508",
    "data" => %{
      "rows" => [
        %{
          "title" => "Jev — contra negativos difíceis",
          "neg" => "negativos",
          "neg_c" => 85,
          "neg_s" => 26,
          "pos" => "positivos",
          "pos_c" => 285,
          "pos_s" => 28,
          "auc" => "0,956"
        },
        %{
          "title" => "Laya — contra negativos difíceis",
          "neg" => "negativos",
          "neg_c" => 165,
          "neg_s" => 32,
          "pos" => "positivos",
          "pos_c" => 215,
          "pos_s" => 32,
          "auc" => "0,508"
        }
      ]
    },
    "caption" =>
      "As curvas são esquemáticas; os valores de AUC são medidos. 0,508 é o que uma moeda entrega.",
    "note" =>
      "**Regra do rótulo, escrita antes:** trata paciente humano, com hora marcada. " <>
        "Farmácia, pet shop e academia ficam de fora."
  },
  %{
    "type" => "text",
    "paragraphs" => [
      "Contra negativos **fáceis** — autopeças, mercearia, banca de jornal — o Laya marca 0,890. É por isso que um teste montado de cabeça o aprova: os negativos que vêm à cabeça são sempre os fáceis."
    ],
    "note" =>
      "A categoria com segunda maior probabilidade média no Laya foi *plano de saúde*, " <>
        "que é negativo. Clínica veterinária passou consultório odontológico."
  },
  %{
    "type" => "section",
    "n" => "04",
    "title" => "Onde o erro cai"
  },
  %{
    "type" => "diagram",
    "form" => "matriz",
    "alt" => "Matriz de confusão do portão de lead com o Jev no limiar 0,44",
    "data" => %{
      "col_a" => "previsto: saúde",
      "col_b" => "previsto: outro",
      "row_a" => "real: saúde",
      "row_b" => "real: outro",
      "metric_a" => "precisão 0,83",
      "metric_b" => "cobertura 0,94",
      "cells" => [
        %{"value" => "68", "label" => "acerto", "accent" => true},
        %{"value" => "4", "label" => "clínica perdida", "tone" => "bad"},
        %{"value" => "14", "label" => "farmácia, vet…", "tone" => "warn"},
        %{"value" => "94", "label" => "acerto", "accent" => true}
      ]
    },
    "caption" =>
      "Limiar 0,44 no Jev: perde 4 clínicas para não deixar passar 14 negativos difíceis."
  },
  %{
    "type" => "section",
    "n" => "05",
    "title" => "Quanto a amostra deixa concluir"
  },
  %{
    "type" => "diagram",
    "form" => "intervalo",
    "alt" =>
      "Com 8 casos o intervalo de confiança cobre quase toda a faixa; com 180 ele se fecha em torno de 0,72",
    "data" => %{
      "ticks" => ["0,4", "0,7", "1,0"],
      "rows" => [
        %{
          "label" => "8 casos",
          "lo" => 0.42,
          "hi" => 0.98,
          "point" => 0.72,
          "note" => "qualquer conclusão cabe"
        },
        %{
          "label" => "180 casos",
          "lo" => 0.647,
          "hi" => 0.790,
          "point" => 0.720,
          "note" => "0,720",
          "accent" => true
        }
      ]
    },
    "caption" =>
      "O mesmo modelo, a mesma pergunta. O que muda é o que você tem direito de afirmar."
  },
  %{
    "type" => "section",
    "n" => "06",
    "title" => "A ordem em que se pergunta"
  },
  %{
    "type" => "diagram",
    "form" => "decisao",
    "alt" =>
      "Primeiro se pergunta se existe sinal; sem sinal o candidato é descartado, com sinal calibra-se o limiar",
    "data" => %{
      "question" => "existe sinal?",
      "no_label" => "não",
      "no" => "descarte o candidato",
      "yes_label" => "sim",
      "yes" => "calibre o limiar",
      "then_a" => "metade A ajusta",
      "then_b" => "metade B reporta"
    },
    "caption" =>
      "AUC responde a primeira pergunta sem depender de corte. O corte é a segunda decisão."
  },
  %{
    "type" => "diagram",
    "form" => "fluxo",
    "alt" =>
      "Um lead do Google Maps passa pela categoria, pelo classificador e por um limiar antes de entrar na campanha",
    "data" => %{
      "steps" => [
        %{"label" => "lead do Maps", "note" => "nome + categoria"},
        %{"label" => "classificador", "note" => "noul", "accent" => true},
        %{"label" => "p = 0,61", "mono" => true},
        %{"label" => "campanha", "note" => "limiar 0,44"}
      ],
      "branch" => %{
        "x" => 228,
        "label" => "abaixo do limiar",
        "note" => "vai para revisão"
      }
    },
    "caption" =>
      "A categoria carrega o sinal. O nome fantasia não vale nada para nenhum dos dois."
  },
  %{
    "type" => "section",
    "n" => "07",
    "title" => "O que a correção de prompt fez"
  },
  %{
    "type" => "text",
    "paragraphs" => [
      "Num segundo caso — separar mensagem automática de mensagem escrita por pessoa — o classificador que já rodava errava quase tudo numa categoria só. Reescrevi o prompt mirando nela."
    ]
  },
  %{
    "type" => "diagram",
    "form" => "antes_depois",
    "alt" =>
      "O prompt novo corrigiu a categoria de automático informal de 2 para 25, mas derrubou humano informal de 25 para 17",
    "data" => %{
      "from_label" => "antigo",
      "to_label" => "novo",
      "max" => 25,
      "rows" => [
        %{"label" => "automático óbvio", "from" => 25, "to" => 25},
        %{"label" => "automático informal", "from" => 2, "to" => 25, "tone" => "good"},
        %{"label" => "humano informal", "from" => 25, "to" => 17, "tone" => "bad"},
        %{"label" => "humano formal", "from" => 25, "to" => 25}
      ]
    },
    "caption" =>
      "Consertou a coluna que eu estava olhando e quebrou a que eu não estava. De 25 casos cada."
  },
  %{
    "type" => "callout",
    "variant" => "bad",
    "title" => "Vinte casos esconderam isso",
    "text" =>
      "Numa amostra de 20, o prompt novo marcou 20 de 20. A regressão só apareceu com 100, porque " <>
        "os cinco casos de humano informal que caíram no sorteio foram justamente os que ele ainda acertava."
  },
  %{
    "type" => "section",
    "n" => "08",
    "title" => "Como a noite se desenrolou"
  },
  %{
    "type" => "diagram",
    "form" => "linha_tempo",
    "alt" =>
      "A sequência de testes ao longo da noite, do primeiro resultado falso ao teste de negação",
    "data" => %{
      "events" => [
        %{
          "time" => "21h",
          "label" => "8 exemplos",
          "note" => "“separação perfeita”",
          "tone" => "bad"
        },
        %{"time" => "23h", "label" => "180 casos", "note" => "AUC 0,508", "accent" => true},
        %{
          "time" => "01h",
          "label" => "teste de negação",
          "note" => "30 segundos",
          "accent" => true
        },
        %{"time" => "03h", "label" => "reservado", "note" => "regressão"}
      ]
    },
    "caption" => "O teste mais barato foi o último que eu rodei."
  },
  %{
    "type" => "quote",
    "text" =>
      "O teste mais caro da noite custou US$ 0,0134. O caro foi o tempo que eu gastei acreditando em oito exemplos.",
    "cite" => nil
  },
  %{
    "type" => "section",
    "n" => "09",
    "title" => "Qual usar"
  },
  %{
    "type" => "text",
    "paragraphs" => [
      "Para composição — negação, número, inferência — só o Jev funciona. Para casamento lexical, os dois entregam, e aí o Laya ganha em latência, custo e privacidade.",
      "O argumento que pode virar o jogo é o peso aberto: o Laya é treinável nos seus rótulos, e o Jev não expõe nada de fine-tuning. Só que treinar é projeto, e só se paga se privacidade ou latência te empurrarem para o local."
    ]
  },
  %{
    "type" => "callout",
    "variant" => "note",
    "title" => "Onde nenhum dos dois entra",
    "text" =>
      "Se já existe um modelo pequeno e barato fazendo o trabalho, trocar raramente paga. " <>
        "O ganho real costuma estar onde não existe classificador nenhum."
  },
  %{
    "type" => "question",
    "text" =>
      "O Jev acertou contagem e ordem de datas nos meus controles, que a documentação dele descreve como fraqueza. Em que tamanho de lista, e com que distância entre datas, isso deixa de valer?"
  },
  %{
    "type" => "source",
    "title" => "Medições próprias, setembro de 2026",
    "note" =>
      "Conjuntos sintéticos construídos por mim. Tudo que aparece como número foi rodado, não estimado. " <>
        "Latência é mediana de 40 chamadas pareadas e intercaladas."
  }
]

# The article's key figure: the one measurement the whole piece exists to show.
# It repeats the distribution block from the body on purpose — the card promises
# a result and the article delivers the same one, rather than a decoration.
hero = %{
  "form" => "distribuicao",
  "alt" =>
    "Jev separa positivos de negativos difíceis com AUC 0,956; no Laya os dois grupos se sobrepõem, com AUC 0,508",
  "caption" => "As curvas são esquemáticas; os valores de AUC são medidos.",
  "data" => %{
    "rows" => [
      %{
        "title" => "Jev — negativos difíceis",
        "neg" => "negativos",
        "neg_c" => 85,
        "neg_s" => 26,
        "pos" => "positivos",
        "pos_c" => 285,
        "pos_s" => 28,
        "auc" => "0,956"
      },
      %{
        "title" => "Laya — negativos difíceis",
        "neg" => "negativos",
        "neg_c" => 165,
        "neg_s" => 32,
        "pos" => "positivos",
        "pos_c" => 215,
        "pos_s" => 32,
        "auc" => "0,508"
      }
    ]
  }
}

{:ok, _post} =
  Content.upsert_post(%{
    title: "Laya x Jev: o que um classificador tipado faz e o que ele não faz",
    subtitle:
      "Dois modelos com a mesma API e um abismo entre eles. Medi negação, contagem e magnitude nos mesmos casos.",
    slug: "laya-x-jev",
    kind: "ensaio",
    status: "published",
    published_at: DateTime.utc_now() |> DateTime.truncate(:second),
    reading_minutes: 11,
    topics: ["avaliação", "classificadores", "método"],
    meta_description:
      "Comparação medida entre Laya e Jev: AUC 0,956 contra 0,508 em negativos difíceis, " <>
        "teste de negação, custo por chamada e latência pareada.",
    hero: hero,
    body: %{"blocks" => blocks},
    author_id: author.id
  })

IO.puts("seed ok — #{author.name}, 1 artigo publicado")
