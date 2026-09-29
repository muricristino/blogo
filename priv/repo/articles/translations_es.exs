# Las versiones en español de los artículos, como datos.
#
# Mismo acuerdo que el archivo en inglés: aquí vive sólo lo que es texto. La
# fecha, el tiempo de lectura, el autor y el tipo los copia la migración desde
# el artículo en portugués, porque son hechos del artículo y no del idioma en
# que está escrito.

texto = fn parrafos -> %{"type" => "text", "paragraphs" => parrafos} end

[
  %{
    of: "sobre",
    language: "es",
    slug: "acerca-de",
    title: "Acerca de",
    subtitle: "Ingeniero de software",
    topics: [],
    meta_description:
      "Escribo sobre lo que mido. Elixir, Rails, Postgres y la parte aburrida de evaluar " <>
        "un modelo antes de ponerlo en producción.",
    hero: nil,
    blocks: [
      texto.([
        "Escribo sobre lo que mido. Elixir, Rails, Postgres y la parte aburrida de evaluar un modelo antes de ponerlo en producción."
      ]),
      texto.(["Escribo desde São Paulo."])
    ]
  },
  %{
    of: "fail-open",
    language: "es",
    slug: "fail-open-cuando-el-fallo-total-se-vuelve-silencio",
    title: "Fail-open: cuando el fallo total se vuelve silencio",
    subtitle:
      "Un `return false` defensivo encima de la línea de log convirtió un 404 en “todo es " <>
        "humano” durante tres meses. El patrón, y cómo detectarlo.",
    topics: ["producción", "observabilidad"],
    meta_description:
      "Un `return false` defensivo encima de la línea de log convirtió un 404 en “todo es " <>
        "humano” durante tres meses. El patrón, y cómo detectarlo.",
    hero: %{
      "form" => "linha_tempo",
      "alt" =>
        "El modelo se retira, el clasificador pasa a responder humano a todo, y tres meses después alguien se da cuenta",
      "caption" => "Ninguna alerta saltó: el return ocurría encima de la línea que registraba.",
      "data" => %{
        "events" => [
          %{"time" => "día 0", "label" => "el modelo se retira", "note" => "404 en cada llamada"},
          %{
            "time" => "día 1",
            "label" => "el fail-open toma el mando",
            "note" => "todo pasa a ser humano",
            "tone" => "bad"
          },
          %{
            "time" => "día 92",
            "label" => "alguien se da cuenta",
            "note" => "por la factura, no por el log",
            "accent" => true
          }
        ]
      }
    },
    blocks: [
      texto.([
        "El clasificador llamaba a un modelo que había sido retirado. Recibía un 404, caía en un `return false` defensivo y clasificaba todo como humano."
      ]),
      texto.([
        "El `catch` era una decisión defendible: mejor dejar pasar algo que silenciar a un cliente de verdad. Pero también convirtió un fallo total en algo invisible, porque el return ocurría encima de la línea que registraba."
      ]),
      %{
        "type" => "callout",
        "variant" => "bad",
        "title" => "La prueba que nadie escribe",
        "text" =>
          "Todo fail-open necesita un contador. Si el camino de error no incrementa nada, no tiene forma de avisarte de que se ha convertido en el camino principal."
      }
    ]
  },
  %{
    of: "conjunto-de-180-casos",
    language: "es",
    slug: "como-armo-un-conjunto-de-180-casos",
    title: "Cómo armo un conjunto de 180 casos",
    subtitle:
      "Un negativo difícil no es lo que al modelo le cuesta — es lo que aparece en la misma " <>
        "consulta. Un método en cuatro pasos, con la planilla.",
    topics: ["evaluación", "método"],
    meta_description:
      "Un negativo difícil no es lo que al modelo le cuesta — es lo que aparece en la misma " <>
        "consulta. Un método en cuatro pasos, con la planilla.",
    hero: %{
      "form" => "antes_depois",
      "alt" =>
        "Con negativos fáciles el modelo marca 0,890; al cambiarlos por negativos difíciles baja a 0,508",
      "caption" => "El modelo es el mismo. Lo que cambió es la población que llega a la decisión.",
      "data" => %{
        "from_label" => "negativos fáciles",
        "to_label" => "negativos difíciles",
        "max" => 100,
        "rows" => [%{"label" => "AUC", "from" => 89, "to" => 51, "tone" => "bad"}]
      }
    },
    blocks: [
      texto.([
        "Ocho ejemplos elegidos de memoria me dieron “separación perfecta”. Los mismos 180 casos, con negativos difíciles, dieron un AUC de 0,508 — lo que entrega una moneda."
      ]),
      texto.(["Toda la diferencia estaba en a quién dejé entrar en el conjunto."]),
      %{
        "type" => "callout",
        "variant" => "warn",
        "title" => "La regla va antes",
        "text" =>
          "Escribe el criterio de la etiqueta en una frase antes de ejecutar nada. Sin eso racionalizas la etiqueta mirando la salida, y ni siquiera te das cuenta de que lo hiciste."
      }
    ]
  },
  %{
    of: "mcnemar-em-ruby",
    language: "es",
    slug: "mcnemar-en-veinte-lineas-de-ruby",
    title: "McNemar en veinte líneas de Ruby",
    subtitle:
      "Comparar dos exactitudes sueltas desperdicia lo más útil que tienes: los dos modelos " <>
        "vieron los mismos ítems.",
    topics: ["evaluación", "rails"],
    meta_description:
      "Comparar dos exactitudes sueltas desperdicia lo más útil que tienes: los dos modelos " <>
        "vieron los mismos ítems.",
    hero: %{
      "form" => "matriz",
      "alt" =>
        "Tabla pareada de McNemar: sólo entran en la prueba las dos casillas en que los modelos discrepan",
      "caption" => "Las casillas de la diagonal no entran en la cuenta — decide la discrepancia.",
      "data" => %{
        "col_a" => "B acierta",
        "col_b" => "B falla",
        "row_a" => "A acierta",
        "row_b" => "A falla",
        "cells" => [
          %{"value" => "142", "label" => "coinciden"},
          %{"value" => "9", "label" => "sólo A acierta", "accent" => true},
          %{"value" => "27", "label" => "sólo B acierta", "accent" => true},
          %{"value" => "2", "label" => "coinciden"}
        ]
      }
    },
    blocks: [
      texto.([
        "Si los dos candidatos se evaluaron sobre los mismos casos, comparar las exactitudes tira el pareamiento a la basura. McNemar mira sólo los casos en que discrepan, que es donde está la información."
      ]),
      %{
        "type" => "code",
        "lang" => "ruby",
        "code" => """
        b = pairs.count { |a, c| a && !c }   # sólo A acierta
        c = pairs.count { |a, cc| cc && !a } # sólo B acierta
        m = b + c
        p_value = 2 * (0..[b, c].min).sum { |i| binom(m, i) } / 2.0**m
        """,
        "caption" => "Con b + c pequeño, usa la forma exacta; la aproximación ji-cuadrado miente."
      }
    ]
  },
  %{
    of: "indice-que-o-postgres-nao-usou",
    language: "es",
    slug: "el-indice-que-postgres-decidio-no-usar",
    title: "El índice que Postgres decidió no usar",
    subtitle:
      "Una noche leyendo `EXPLAIN ANALYZE` para descubrir que la estadística estaba vieja y " <>
        "el planificador tenía razón.",
    topics: ["postgres"],
    meta_description:
      "Una noche leyendo `EXPLAIN ANALYZE` para descubrir que la estadística estaba vieja y " <>
        "el planificador tenía razón.",
    hero: %{
      "form" => "decisao",
      "alt" =>
        "El planificador usa el índice sólo cuando la selectividad estimada es baja; por encima prefiere recorrer la tabla",
      "caption" => "El índice existía. Lo que estaba mal era la estimación.",
      "data" => %{
        "question" => "¿selectividad baja?",
        "yes_label" => "sí",
        "yes" => "index scan",
        "no_label" => "no",
        "no" => "seq scan — y tiene razón",
        "then_a" => "estadística desactualizada",
        "then_b" => "cambia la respuesta"
      }
    },
    blocks: [
      texto.([
        "El índice existía, la consulta filtraba exactamente por esa columna, y el planificador insistía en un seq scan. La tentación es forzarlo con `enable_seqscan = off` y seguir con tu vida."
      ]),
      texto.([
        "`ANALYZE` lo resolvió en un segundo. La tabla había crecido 40 veces desde la última recolección de estadísticas, y el planificador estimaba con números de otro mundo."
      ])
    ]
  },
  %{
    of: "tres-perguntas-antes-de-trocar",
    language: "es",
    slug: "tres-preguntas-antes-de-cambiar-de-proveedor",
    title: "Nota: tres preguntas antes de cambiar de proveedor",
    subtitle:
      "Una nota corta. La tercera es la única que importa, y casi nadie la hace.",
    topics: ["notas cortas"],
    meta_description:
      "Una nota corta. La tercera es la única que importa, y casi nadie la hace.",
    hero: %{
      "form" => "fluxo",
      "alt" =>
        "Tres preguntas en secuencia antes de cambiar de proveedor: qué mides, contra qué, y qué pasa si desaparece",
      "caption" => "La tercera es la única que sobrevive al contrato.",
      "data" => %{
        "steps" => [
          %{"label" => "¿qué mides?"},
          %{"label" => "¿contra qué?"},
          %{"label" => "¿y si desaparece?", "accent" => true}
        ]
      }
    },
    blocks: [
      texto.([
        "**Uno.** Lo que hay hoy ¿es malo, o está roto? Son cosas distintas, y la segunda se arregla gratis.",
        "**Dos.** ¿La ganancia medida cubre el coste de una dependencia más?",
        "**Tres.** Si el proveedor nuevo desaparece en seis meses, ¿qué te pasa a ti?"
      ])
    ]
  }
]
