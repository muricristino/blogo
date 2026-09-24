# O artigo sobre o learno, como dado.
#
# Fica separado da migração que o insere porque um texto de trinta blocos dentro
# de uma migração é um texto que ninguém revisa. A migração lê este arquivo.

texto = fn paragrafos -> %{"type" => "text", "paragraphs" => paragrafos} end

%{
  title: "Fluência é fácil de fingir",
  subtitle:
    "Uma skill que ensina ao longo de meses e trata o aluno como eu trato um classificador: " <>
      "definindo o critério antes, medindo o que importa e desconfiando do que parece fácil.",
  slug: "fluencia-e-facil-de-fingir",
  kind: "ensaio",
  topics: ["aprendizado", "método", "avaliação"],
  reading_minutes: 9,
  meta_description:
    "O learno define o critério de vitória antes da primeira aula, mede retenção em vez de " <>
      "fluência e compara o que o aluno achou fácil com o que ele acertou.",
  hero: %{
    "form" => "matriz",
    "alt" =>
      "Matriz cruzando o que o aluno achou fácil com o que ele acertou; a casa perigosa é achou fácil e foi mal",
    "caption" => "A casa de cima à direita é a única que ensina alguma coisa.",
    "data" => %{
      "col_a" => "acertou",
      "col_b" => "errou",
      "row_a" => "achou fácil",
      "row_b" => "achou difícil",
      "cells" => [
        %{"value" => "sabe", "label" => "siga em frente"},
        %{"value" => "o ponto cego", "label" => "não sabe que não sabe", "accent" => true},
        %{"value" => "está aprendendo", "label" => "esforço rendeu"},
        %{"value" => "sabe o que falta", "label" => "já pede ajuda"}
      ]
    }
  },
  blocks: [
    texto.([
      "Um amigo me disse que estava indo bem em inglês. Assistia série sem legenda, entendia reunião, lia documentação. Seis meses depois travou numa entrevista em que precisou *produzir* uma frase sob pressão, e concluiu que tinha regredido.",
      "Ele não regrediu. Ele nunca tinha medido a coisa certa."
    ]),
    %{
      "type" => "keynumbers",
      "items" => [
        %{"value" => "2", "label" => "portões que uma missão precisa passar"},
        %{"value" => "75", "label" => "nota que confirma um conceito"},
        %{"value" => "3", "label" => "fontes de domínio, com proveniência"}
      ]
    },
    texto.([
      "O **learno** é uma skill que ensina uma coisa ao longo de várias sessões. Ela escreve as aulas, agenda revisões, mantém um banco do que você demonstrou e abre cada encontro dizendo onde você está. Fui ler o que ela faz esperando um gerador de conteúdo, e encontrei um conjunto de decisões sobre medição que eu reconheci — são as mesmas que eu uso quando avalio um modelo."
    ]),
    %{"type" => "section", "n" => "01", "title" => "Uma missão que pode ser perdida"},
    texto.([
      "A primeira coisa que ela faz não é ensinar. É recusar.",
      "Antes de gerar qualquer aula, a skill entrevista até a missão passar por dois portões: existe um jeito de nós dois sabermos que você chegou, e este motor consegue te levar até lá. *Aprender inglês* falha nos dois. *Passar na prova teórica do Detran* passa. *Resolver a maioria dos mediums do LeetCode sem ajuda* passa."
    ]),
    %{
      "type" => "diagram",
      "form" => "decisao",
      "alt" =>
        "A missão pode ser vencida? Sem critério de vitória, nada é ensinado; com critério, a aula é gerada",
      "data" => %{
        "question" => "dá para perder?",
        "no_label" => "não",
        "no" => "entrevista de novo",
        "yes_label" => "sim",
        "yes" => "gera a primeira aula",
        "then_a" => "critério escrito",
        "then_b" => "antes do conteúdo"
      },
      "caption" => "Uma meta que não dá para perder também não dá para ganhar.",
      "note" =>
        "**A mesma regra do rótulo.** Num conjunto de teste, escrever o critério antes " <>
          "impede que ele se molde ao resultado. Numa aula, impede que *estudei bastante* " <>
          "vire prova de que funcionou."
    },
    texto.([
      "Isso é a regra do rótulo, aplicada a gente. Quando eu monto um conjunto de teste, escrevo o critério antes de olhar qualquer saída — senão o critério se molda ao resultado e eu me convenço de que deu certo. Aqui é a mesma coisa: sem um alvo que dê para errar, *estudei bastante* vira prova de progresso."
    ]),
    %{"type" => "section", "n" => "02", "title" => "O que se mede não é o que se sente"},
    texto.([
      "A skill separa duas coisas que costumam ser tratadas como uma: **fluência** e **força de armazenamento**.",
      "Fluência é conseguir agora. Reconhecer a palavra, acompanhar o raciocínio, entender a explicação enquanto ela acontece. É a sensação de estar aprendendo — e é fácil de fingir, inclusive para si mesmo, porque o material está na tela e o contexto faz metade do trabalho.",
      "Força de armazenamento é conseguir daqui a três semanas, sem o material à vista, com a pergunta formulada de outro jeito. É a única que importa e é a que ninguém mede, porque medi-la é desconfortável."
    ]),
    %{
      "type" => "diagram",
      "form" => "antes_depois",
      "alt" =>
        "Reconhecer uma resposta é muito mais fácil do que produzi-la; a distância entre as duas é o que se perde",
      "data" => %{
        "from_label" => "reconhecer",
        "to_label" => "produzir",
        "max" => 100,
        "rows" => [
          %{"label" => "com o material à vista", "from" => 92, "to" => 61},
          %{"label" => "três semanas depois", "from" => 78, "to" => 34, "tone" => "bad"}
        ]
      },
      "caption" => "As barras são ilustrativas; a ordem entre elas é o que a literatura mostra.",
      "note" =>
        "É por isso que toda aula exige pelo menos um **recall** — resposta escrita do zero. " <>
          "Múltipla escolha entra para variar, nunca para substituir."
    },
    texto.([
      "A consequência prática é que a skill nunca aceita reconhecimento como evidência. Toda aula precisa de pelo menos uma seção de resposta livre, escrita do zero. Quiz de múltipla escolha existe para variar o ritmo, e a regra é explícita: não substitui, porque reconhecer uma resposta é mais fácil do que produzi-la."
    ]),
    %{"type" => "section", "n" => "03", "title" => "O dado que quase ninguém coleta"},
    texto.([
      "Esta é a parte que me fez escrever o artigo.",
      "Ao fim de cada aula, a skill pergunta duas coisas — o que confundiu, e o que pareceu fácil demais — e então **cruza a resposta com a nota**. Não é uma pesquisa de satisfação. É a coleta do único dado que o aluno tem e o sistema não."
    ]),
    %{
      "type" => "callout",
      "variant" => "note",
      "title" => "A frase que resume",
      "text" =>
        "Uma seção que a pessoa achou fácil e na qual tirou 55 vale mais do que qualquer um dos dois fatos isolados: é a lacuna que ela não consegue ver."
    },
    texto.([
      "Achar fácil e ir mal é o ponto cego. A pessoa não vai pedir ajuda ali, porque para ela aquilo está resolvido. Achar difícil e ir bem é o oposto e não é problema: ela já sabe onde pisar com cuidado.",
      "É o mesmo raciocínio de olhar a matriz de confusão em vez da acurácia. O número agregado diz que o modelo acerta 87%; a matriz diz *quais* ele erra, e é ali que se decide se dá para usar. Nota agregada de aula diz que foi bem; o cruzamento diz onde ela vai desabar daqui a um mês."
    ]),
    %{"type" => "section", "n" => "04", "title" => "A rubrica antes da resposta"},
    texto.([
      "Quando um bloco de conceitos fecha, a skill propõe um projeto. E aí vem outra decisão que eu não esperava encontrar:",
      "**A rubrica vai no enunciado, antes de a pessoa começar, e ela pode ler.** Quatro a seis critérios, de uma fonte canônica quando existe. A justificativa está escrita lá: para que as traves não possam ser movidas depois que você viu a resposta — e para que a pessoa saiba o que é bom enquanto ainda dá tempo de agir sobre isso."
    ]),
    %{
      "type" => "question",
      "text" =>
        "Quantas avaliações de trabalho, de código e de candidato você já viu em que o critério só foi formulado depois da entrega?"
    },
    texto.([
      "E há uma regra sobre o que conta como entrega que eu achei a mais afiada do conjunto: **o que se entrega é um artefato no meio da disciplina, nunca uma descrição de um**. Código que roda, não um documento sobre como você construiria. Uma demonstração, não um resumo da técnica. Algo falado na língua, não um resumo da regra gramatical.",
      "O motivo é econômico: pedir a descrição testa explicação, e explicação já foi testada na aula. Pedir descrição de novo é escrever um teach-back longo e chamar de projeto."
    ]),
    %{
      "type" => "table",
      "headers" => ["Disciplina", "A entrega é", "Não é"],
      "rows" => [
        ["Programação", "código que roda nos casos do enunciado", "o documento de arquitetura"],
        ["Matemática", "uma prova, ou o contraexemplo que mata a afirmação", "a explicação da técnica"],
        ["Uma língua", "algo falado ou escrito *na* língua", "o resumo da regra"],
        ["Filosofia", "um argumento defendido contra a objeção mais forte", "o resumo da posição"]
      ],
      "caption" => "A tabela existe porque a tentação de aceitar a descrição é universal."
    },
    %{"type" => "section", "n" => "05", "title" => "Quando a culpa é do método"},
    texto.([
      "A última decisão é sobre o que fazer quando os números vêm ruins três vezes seguidas.",
      "A instrução é dizer em voz alta que **a abordagem não está funcionando — não que o aluno é lento**. É uma escolha de atribuição, e ela muda o que acontece em seguida: se o problema é o aluno, a saída é insistir; se é o método, a saída é trocar a analogia, dividir o conceito, buscar outra fonte."
    ]),
    %{
      "type" => "diagram",
      "form" => "linha_tempo",
      "alt" =>
        "Três medições seguidas abaixo de setenta e cinco: o gatilho não é insistir, é trocar a abordagem",
      "data" => %{
        "events" => [
          %{"time" => "1ª", "label" => "abaixo de 75", "note" => "pode ser o dia"},
          %{"time" => "2ª", "label" => "abaixo de 75", "note" => "pode ser o tema"},
          %{
            "time" => "3ª",
            "label" => "abaixo de 75",
            "note" => "é o método",
            "accent" => true
          }
        ]
      },
      "caption" => "O limiar é declarado antes, e não se move quando incomoda."
    },
    texto.([
      "Um sistema de ensino que atribui todo fracasso ao aluno nunca precisa mudar. É confortável e é inútil — do mesmo jeito que um classificador avaliado só contra negativos fáceis nunca precisa melhorar."
    ]),
    %{
      "type" => "marginnote",
      "text" =>
        "Domínio tem **três fontes** com proveniência registrada: a conversa, a validação " <>
          "por modelo e o projeto. E a regra: *nunca reduza domínio a nota*."
    },
    %{"type" => "section", "n" => "06", "title" => "O que eu levei"},
    texto.([
      "Não escrevi isto para recomendar uma ferramenta. Escrevi porque encontrei, num lugar onde não procurava, a lista de decisões que eu queria ter escrito sobre avaliação.",
      "Definir o critério antes de olhar o resultado. Medir a coisa que sobrevive, não a que agrada. Coletar o dado que o sujeito tem e o sistema não, e cruzar os dois. Recusar a descrição quando o que importa é a coisa. E, quando a medida vem ruim três vezes, suspeitar do instrumento antes de suspeitar do objeto.",
      "Serve para ensinar alguém. Serve para avaliar um modelo. Desconfio que sirva para quase tudo em que a gente se convence rápido demais de que está dando certo."
    ]),
    %{
      "type" => "source",
      "url" => "https://github.com/muricristino/learno",
      "title" => "learno — SKILL.md",
      "note" =>
        "As citações vêm do texto da skill. Os números de barra do diagrama de fluência são ilustrativos; a ordem entre eles é o que a literatura de repetição espaçada mostra."
    }
  ]
}
