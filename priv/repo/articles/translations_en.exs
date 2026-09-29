# The English versions of the articles, as data.
#
# Only what is text lives here. Everything else — the publication date, the
# reading time, the author, the kind — is copied from the Portuguese article by
# the migration that reads this file: those are facts about the article, not
# about the language it is written in, and two copies of a fact is one fact too
# many.
#
# `of:` is the slug of the article this is a version of. The migration finds it,
# takes its translation group, and puts this one in the same one.

texto = fn paragrafos -> %{"type" => "text", "paragraphs" => paragrafos} end

[
  %{
    of: "sobre",
    language: "en",
    slug: "about",
    title: "About",
    subtitle: "Software engineer",
    topics: [],
    meta_description:
      "I write about what I measure. Elixir, Rails, Postgres, and the tedious part of " <>
        "evaluating a model before it goes to production.",
    hero: nil,
    blocks: [
      texto.([
        "I write about what I measure. Elixir, Rails, Postgres, and the tedious part of evaluating a model before it goes to production."
      ]),
      texto.(["I write from São Paulo."])
    ]
  },
  %{
    of: "fail-open",
    language: "en",
    slug: "fail-open-when-total-failure-goes-silent",
    title: "Fail-open: when total failure goes silent",
    subtitle:
      "A defensive `return false` above the log line turned 404 into “everyone is human” " <>
        "for three months. The pattern, and how to catch it.",
    topics: ["production", "observability"],
    meta_description:
      "A defensive `return false` above the log line turned 404 into “everyone is human” " <>
        "for three months. The pattern, and how to catch it.",
    hero: %{
      "form" => "linha_tempo",
      "alt" =>
        "The model is retired, the classifier starts answering human to everything, and three months later somebody notices",
      "caption" => "No alert fired: the return happened above the line that logged.",
      "data" => %{
        "events" => [
          %{"time" => "day 0", "label" => "model is retired", "note" => "404 on every call"},
          %{
            "time" => "day 1",
            "label" => "fail-open takes over",
            "note" => "everything becomes human",
            "tone" => "bad"
          },
          %{
            "time" => "day 92",
            "label" => "somebody notices",
            "note" => "from the invoice, not the log",
            "accent" => true
          }
        ]
      }
    },
    blocks: [
      texto.([
        "The classifier was calling a model that had been retired. It got a 404, fell into a defensive `return false`, and classified everything as human."
      ]),
      texto.([
        "The `catch` was a defensible decision: better to let something through than to silence a real customer. But it also turned a total outage into something invisible, because the return happened above the line that did the logging."
      ]),
      %{
        "type" => "callout",
        "variant" => "bad",
        "title" => "The test nobody writes",
        "text" =>
          "Every fail-open needs a counter. If the error path increments nothing, it has no way of telling you it has become the main path."
      }
    ]
  },
  %{
    of: "conjunto-de-180-casos",
    language: "en",
    slug: "how-i-build-a-180-case-test-set",
    title: "How I build a 180-case test set",
    subtitle:
      "A hard negative is not what the model finds hard — it is what turns up in the same " <>
        "query. A method in four steps, with the spreadsheet.",
    topics: ["evaluation", "method"],
    meta_description:
      "A hard negative is not what the model finds hard — it is what turns up in the same " <>
        "query. A method in four steps, with the spreadsheet.",
    hero: %{
      "form" => "antes_depois",
      "alt" =>
        "With easy negatives the model scores 0.890; swapping in hard negatives drops it to 0.508",
      "caption" => "The model is the same. What changed is the population reaching the decision.",
      "data" => %{
        "from_label" => "easy negatives",
        "to_label" => "hard negatives",
        "max" => 100,
        "rows" => [%{"label" => "AUC", "from" => 89, "to" => 51, "tone" => "bad"}]
      }
    },
    blocks: [
      texto.([
        "Eight examples picked off the top of my head gave me “perfect separation”. The same 180 cases, with hard negatives, gave AUC 0.508 — what a coin delivers."
      ]),
      texto.(["The entire difference was in who I let into the set."]),
      %{
        "type" => "callout",
        "variant" => "warn",
        "title" => "The rule comes first",
        "text" =>
          "Write the labelling criterion down in one sentence before running anything. Without that you rationalise the label while looking at the output, and you do not even notice you did."
      }
    ]
  },
  %{
    of: "mcnemar-em-ruby",
    language: "en",
    slug: "mcnemar-in-twenty-lines-of-ruby",
    title: "McNemar in twenty lines of Ruby",
    subtitle:
      "Comparing two loose accuracies throws away the most useful thing you have: both " <>
        "models saw the same items.",
    topics: ["evaluation", "rails"],
    meta_description:
      "Comparing two loose accuracies throws away the most useful thing you have: both " <>
        "models saw the same items.",
    hero: %{
      "form" => "matriz",
      "alt" =>
        "McNemar's paired table: only the two cells where the models disagree enter the test",
      "caption" => "The diagonal cells stay out of the sum — disagreement is what decides.",
      "data" => %{
        "col_a" => "B right",
        "col_b" => "B wrong",
        "row_a" => "A right",
        "row_b" => "A wrong",
        "cells" => [
          %{"value" => "142", "label" => "they agree"},
          %{"value" => "9", "label" => "only A is right", "accent" => true},
          %{"value" => "27", "label" => "only B is right", "accent" => true},
          %{"value" => "2", "label" => "they agree"}
        ]
      }
    },
    blocks: [
      texto.([
        "If both candidates were evaluated on the same cases, comparing accuracies throws the pairing away. McNemar looks only at the cases where they disagree, which is where the information is."
      ]),
      %{
        "type" => "code",
        "lang" => "ruby",
        "code" => """
        b = pairs.count { |a, c| a && !c }   # only A is right
        c = pairs.count { |a, cc| cc && !a } # only B is right
        m = b + c
        p_value = 2 * (0..[b, c].min).sum { |i| binom(m, i) } / 2.0**m
        """,
        "caption" =>
          "With b + c small, use the exact form; the chi-squared approximation lies."
      }
    ]
  },
  %{
    of: "indice-que-o-postgres-nao-usou",
    language: "en",
    slug: "the-index-postgres-decided-not-to-use",
    title: "The index Postgres decided not to use",
    subtitle:
      "A night reading `EXPLAIN ANALYZE` to find that the statistics were stale and the " <>
        "planner was right.",
    topics: ["postgres"],
    meta_description:
      "A night reading `EXPLAIN ANALYZE` to find that the statistics were stale and the " <>
        "planner was right.",
    hero: %{
      "form" => "decisao",
      "alt" =>
        "The planner uses the index only when estimated selectivity is low; above that it prefers to scan the table",
      "caption" => "The index was there. It was the estimate that was wrong.",
      "data" => %{
        "question" => "low selectivity?",
        "yes_label" => "yes",
        "yes" => "index scan",
        "no_label" => "no",
        "no" => "seq scan — and it is right",
        "then_a" => "stale statistics",
        "then_b" => "change the answer"
      }
    },
    blocks: [
      texto.([
        "The index existed, the query filtered on exactly that column, and the planner kept insisting on a seq scan. The temptation is to force it with `enable_seqscan = off` and get on with your life."
      ]),
      texto.([
        "`ANALYZE` fixed it in a second. The table had grown 40x since the last statistics run, and the planner was estimating with numbers from another world."
      ])
    ]
  },
  %{
    of: "tres-perguntas-antes-de-trocar",
    language: "en",
    slug: "three-questions-before-switching-vendors",
    title: "Note: three questions before switching vendors",
    subtitle: "A short note. The third is the only one that matters, and almost nobody asks it.",
    topics: ["short notes"],
    meta_description:
      "A short note. The third is the only one that matters, and almost nobody asks it.",
    hero: %{
      "form" => "fluxo",
      "alt" =>
        "Three questions in sequence before switching vendors: what you measure, against what, and what happens if they disappear",
      "caption" => "The third is the only one that outlives the contract.",
      "data" => %{
        "steps" => [
          %{"label" => "what do you measure?"},
          %{"label" => "against what?"},
          %{"label" => "what if they vanish?", "accent" => true}
        ]
      }
    },
    blocks: [
      texto.([
        "**One.** Is what you have bad, or is it broken? Those are different things, and the second one gets fixed for free.",
        "**Two.** Does the measured gain cover the cost of one more dependency?",
        "**Three.** If the new vendor disappears in six months, what happens to you?"
      ])
    ]
  }
]
