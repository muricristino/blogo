defmodule Blogo.Repo.Migrations.BackfillHeroes do
  use Ecto.Migration

  @moduledoc """
  The articles already in production predate the hero column, and seeds only run
  on an empty database — so nothing else would ever fill it for them, and every
  card would render without its figure.

  The values are written as literal SQL rather than through the schema: a data
  migration that goes through `Blogo.Content.Post` breaks the day the schema
  changes, months after this ran. `WHERE hero IS NULL` keeps it a no-op on a
  database that was seeded with the heroes already in place.
  """

  def up do
    execute("""
    UPDATE posts SET hero = '{"alt": "Jev separa positivos de negativos difíceis com AUC 0,956; no Laya os dois grupos se sobrepõem, com AUC 0,508", "caption": "As curvas são esquemáticas; os valores de AUC são medidos.", "data": {"rows": [{"auc": "0,956", "neg": "negativos", "neg_c": 85, "neg_s": 26, "pos": "positivos", "pos_c": 285, "pos_s": 28, "title": "Jev — negativos difíceis"}, {"auc": "0,508", "neg": "negativos", "neg_c": 165, "neg_s": 32, "pos": "positivos", "pos_c": 215, "pos_s": 32, "title": "Laya — negativos difíceis"}]}, "form": "distribuicao"}'::jsonb
     WHERE slug = 'laya-x-jev' AND hero IS NULL
    """)

    execute("""
    UPDATE posts SET hero = '{"alt": "O modelo é descontinuado, o classificador passa a responder humano para tudo, e três meses depois alguém percebe", "caption": "Nenhum alerta disparou: o retorno acontecia antes da linha que logava.", "data": {"events": [{"label": "modelo sai do ar", "note": "404 em toda chamada", "time": "dia 0"}, {"label": "fail-open assume", "note": "tudo vira humano", "time": "dia 1", "tone": "bad"}, {"accent": true, "label": "alguém percebe", "note": "pela fatura, não pelo log", "time": "dia 92"}]}, "form": "linha_tempo"}'::jsonb
     WHERE slug = 'fail-open' AND hero IS NULL
    """)

    execute("""
    UPDATE posts SET hero = '{"alt": "Com negativos fáceis o modelo marca 0,890; trocando por negativos difíceis cai para 0,508", "caption": "O modelo é o mesmo. O que mudou foi a população que chega à decisão.", "data": {"from_label": "negativos fáceis", "max": 100, "rows": [{"from": 89, "label": "AUC", "to": 51, "tone": "bad"}], "to_label": "negativos difíceis"}, "form": "antes_depois"}'::jsonb
     WHERE slug = 'conjunto-de-180-casos' AND hero IS NULL
    """)

    execute("""
    UPDATE posts SET hero = '{"alt": "Tabela pareada de McNemar: só as duas casas em que os modelos discordam entram no teste", "caption": "As casas da diagonal não entram na conta — é a discordância que decide.", "data": {"cells": [{"label": "concordam", "value": "142"}, {"accent": true, "label": "só A acerta", "value": "9"}, {"accent": true, "label": "só B acerta", "value": "27"}, {"label": "concordam", "value": "2"}], "col_a": "B acerta", "col_b": "B erra", "row_a": "A acerta", "row_b": "A erra"}, "form": "matriz"}'::jsonb
     WHERE slug = 'mcnemar-em-ruby' AND hero IS NULL
    """)

    execute("""
    UPDATE posts SET hero = '{"alt": "O planejador só usa o índice quando a seletividade estimada é baixa; acima disso prefere varrer a tabela", "caption": "O índice existia. A estimativa é que estava errada.", "data": {"no": "seq scan — e está certo", "no_label": "não", "question": "seletividade baixa?", "then_a": "estatística desatualizada", "then_b": "muda a resposta", "yes": "index scan", "yes_label": "sim"}, "form": "decisao"}'::jsonb
     WHERE slug = 'indice-que-o-postgres-nao-usou' AND hero IS NULL
    """)

    execute("""
    UPDATE posts SET hero = '{"alt": "Três perguntas em sequência antes de trocar de fornecedor: mede, compara, e o que acontece se ele sumir", "caption": "A terceira é a única que sobrevive ao contrato.", "data": {"steps": [{"label": "o que você mede?"}, {"label": "contra o quê?"}, {"accent": true, "label": "e se ele sumir?"}]}, "form": "fluxo"}'::jsonb
     WHERE slug = 'tres-perguntas-antes-de-trocar' AND hero IS NULL
    """)
  end

  # The column itself is dropped by the migration that added it; there is no
  # previous value to restore here.
  def down, do: :ok
end
