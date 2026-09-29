# The hero diagram of each translated article, keyed by the translation's slug.
#
# It does not live in the markdown file because the hero is a column of its own,
# not a block in the body. And it cannot simply be copied from the original,
# because a diagram has words inside it: the labels are the article's finding
# stated in the reader's language. The numbers are the same — they are
# measurements, and a measurement does not change language.

%{
  "laya-vs-jev-typed-classifier" => %{
    "form" => "distribuicao",
    "alt" =>
      "Jev separates positives from hard negatives with AUC 0.956; in Laya the two groups overlap, with AUC 0.508",
    "caption" => "The curves are schematic; the AUC values are measured.",
    "data" => %{
      "rows" => [
        %{
          "title" => "Jev — hard negatives",
          "auc" => "0.956",
          "pos" => "positives",
          "neg" => "negatives",
          "pos_c" => 285,
          "pos_s" => 28,
          "neg_c" => 85,
          "neg_s" => 26
        },
        %{
          "title" => "Laya — hard negatives",
          "auc" => "0.508",
          "pos" => "positives",
          "neg" => "negatives",
          "pos_c" => 215,
          "pos_s" => 32,
          "neg_c" => 165,
          "neg_s" => 32
        }
      ]
    }
  },
  "laya-contra-jev-clasificador-tipado" => %{
    "form" => "distribuicao",
    "alt" =>
      "Jev separa positivos de negativos difíciles con AUC 0,956; en Laya los dos grupos se solapan, con AUC 0,508",
    "caption" => "Las curvas son esquemáticas; los valores de AUC están medidos.",
    "data" => %{
      "rows" => [
        %{
          "title" => "Jev — negativos difíciles",
          "auc" => "0,956",
          "pos" => "positivos",
          "neg" => "negativos",
          "pos_c" => 285,
          "pos_s" => 28,
          "neg_c" => 85,
          "neg_s" => 26
        },
        %{
          "title" => "Laya — negativos difíciles",
          "auc" => "0,508",
          "pos" => "positivos",
          "neg" => "negativos",
          "pos_c" => 215,
          "pos_s" => 32,
          "neg_c" => 165,
          "neg_s" => 32
        }
      ]
    }
  },
  "fluency-is-easy-to-fake" => %{
    "form" => "matriz",
    "alt" =>
      "A matrix crossing what the student found easy against what they got right; the dangerous cell is found it easy and did badly",
    "caption" => "The top-right cell is the only one that teaches anything.",
    "data" => %{
      "col_a" => "got it right",
      "col_b" => "got it wrong",
      "row_a" => "found it easy",
      "row_b" => "found it hard",
      "cells" => [
        %{"value" => "knows it", "label" => "move on"},
        %{"value" => "the blind spot", "label" => "does not know they do not know", "accent" => true},
        %{"value" => "is learning", "label" => "the effort paid off"},
        %{"value" => "knows what is missing", "label" => "already asks for help"}
      ]
    }
  },
  "la-fluidez-es-facil-de-fingir" => %{
    "form" => "matriz",
    "alt" =>
      "Matriz que cruza lo que el alumno encontró fácil con lo que acertó; la casilla peligrosa es encontrarlo fácil y salir mal",
    "caption" => "La casilla de arriba a la derecha es la única que enseña algo.",
    "data" => %{
      "col_a" => "acertó",
      "col_b" => "falló",
      "row_a" => "le pareció fácil",
      "row_b" => "le pareció difícil",
      "cells" => [
        %{"value" => "lo sabe", "label" => "sigue adelante"},
        %{"value" => "el punto ciego", "label" => "no sabe que no sabe", "accent" => true},
        %{"value" => "está aprendiendo", "label" => "el esfuerzo rindió"},
        %{"value" => "sabe qué le falta", "label" => "ya pide ayuda"}
      ]
    }
  }
}
