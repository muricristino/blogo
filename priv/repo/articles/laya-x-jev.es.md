---
titulo: Laya contra Jev: lo que hace un clasificador tipado y lo que no
resumo: Dos modelos con la misma API y un abismo entre ellos. Medí negación, conteo y magnitud sobre los mismos casos.
endereco: laya-contra-jev-clasificador-tipado
tipo: artigo
marcadores: [evaluación, clasificadores, método]
busca: Comparación medida entre Laya y Jev - AUC 0,956 contra 0,508 en negativos difíciles, prueba de negación, coste por llamada y latencia pareada.
---

@capitular
Dos modelos prometen lo mismo: en vez de generar texto, devolver una decisión tipada con probabilidad. **Jev**, de TypeSafe, es una API cerrada en beta. **Laya** es de pesos abiertos bajo Apache-2.0, y corre en tu Mac.

Pasé una noche midiendo los dos sobre los mismos casos. La diferencia no es de grado.
^ **Sobre los números.** Conjuntos sintéticos, construidos por mí. Todo lo que aparece aquí se ejecutó, no se estimó.

:::numeros
0,956 | AUC de Jev contra negativos difíciles
0,508 | AUC de Laya en los mismos casos
1,70x | Jev más rápido, mediana de 40 llamadas pareadas
:::
^ Mismos casos, mismas preguntas, medidos la misma noche. Lo que separa a los dos no es la exactitud de punta: es negación, magnitud numérica y conteo.

## 01 Qué hace cada uno

Los dos exponen la misma API: envías un estado y preguntas tipadas, y recibes probabilidades. Tres tipos de pregunta, con los mismos nombres en ambos — `noul` para sí o no, `choice` para elegir una opción, `score` para niveles ordenados.

Laya deja su arquitectura a la vista: es un encoder bidireccional de la familia BERT (`ModernBERT-large` en el checkpoint en inglés, `mmBERT-base` en el multilingüe) con cabezas de decisión encima. 421 y 322 millones de parámetros. TypeSafe no publica nada equivalente sobre Jev.

|  | Jev 1.13 | Laya multilingüe |
| --- | --- | --- |
| Dónde corre | la API de TypeSafe | tu hardware, vía MLX |
| Licencia | beta, sin términos publicados | Apache-2.0 |
| Parámetros | no divulgado | 322M |
| Ventana de contexto | 32.000 tokens | 1.024 tokens |
| Entrenable con tus datos | no | sí |
| Coste por 1M de llamadas | US$ 13,38 | cero, más allá de la energía |
| Latencia mediana | 295 ms | 26 ms |
+ Las dos últimas filas miden cosas distintas: una incluye la red, la otra no.
^ **Ventana.** 1.024 tokens parece poco, pero ninguno de mis casos pasó de 400.

## 02 La prueba que los separa en treinta segundos

Antes de armar un conjunto, ejecuta negación. Es una línea y no necesita ninguna etiqueta.

```bash
# pregunta: "¿esta persona quiere cancelar el servicio?"

"quiero cancelar mi suscripción"        laya 0,9912   jev 0,97
"no quiero cancelar, sólo una duda"     laya 0,7123   jev 0,04
"de ninguna manera voy a cancelar"      laya 0,9912   jev 0,05
```
+ En Laya, la frase que niega da exactamente la misma nota que la que afirma.
^ **No cuesta nada.** Seis llamadas, sin etiquetas, y descarta a la mayoría de los candidatos.

Laya ve la palabra *cancelar* y decide. Es una firma de bolsa de palabras, y basta para descartarlo como detector de intención: "no me mandes la factura" y "esto no es urgente" dispararían igual.

El mismo patrón aparece en conteo y en magnitud numérica. Con las mismas palabras y cambiando sólo el número de ítems, Laya responde "sí" para cualquier lista. Y entre unos ingresos de R$ 900 y unos de R$ 60.000, no se mueve nada.

:::aviso warn La regla que explica a los dos
Laya responde bien a *¿este texto afirma X?* y mal a *infiere X a partir de este texto*. El sentimiento funciona porque la frase expresa el sentimiento. Negación, conteo y comparación numérica exigen componer, y ahí es donde se detiene.
:::

## 03 En el conjunto que importa

Armé 180 casos de calificación de leads, con una regla escrita antes de ejecutar nada: positivo es quien presta atención sanitaria a un paciente humano con cita previa.

La mitad de los negativos es **difícil** a propósito — farmacia, clínica veterinaria, gimnasio, estética, seguro de salud. Todo lo que huele a salud sin encajar en la regla. Esa es la población que aparece en una búsqueda real.

:::diagrama distribuicao
alt: Jev separa positivos de negativos difíciles con AUC 0,956; en Laya los dos grupos se solapan, con AUC 0,508
{"rows":[{"auc":"0,956","neg":"negativos","neg_c":85,"neg_s":26,"pos":"positivos","pos_c":285,"pos_s":28,"title":"Jev — contra negativos difíciles"},{"auc":"0,508","neg":"negativos","neg_c":165,"neg_s":32,"pos":"positivos","pos_c":215,"pos_s":32,"title":"Laya — contra negativos difíciles"}]}
:::
+ Las curvas son esquemáticas; los valores de AUC están medidos. 0,508 es lo que entrega una moneda.
^ **Regla de la etiqueta, escrita antes:** atiende a un paciente humano, con cita previa. Farmacia, tienda de mascotas y gimnasio quedan fuera.

Contra negativos **fáciles** — repuestos, tienda de barrio, quiosco — Laya marca 0,890. Por eso una prueba armada de memoria lo aprueba: los negativos que vienen a la cabeza son siempre los fáciles.
^ La categoría con la segunda mayor probabilidad media en Laya fue *seguro de salud*, que es negativo. Una clínica veterinaria superó a una consulta dental.

## 04 Dónde cae el error

:::diagrama matriz
alt: Matriz de confusión de la puerta de leads con Jev en el umbral 0,44
{"cells":[{"accent":true,"label":"acierto","value":"68"},{"label":"clínica perdida","tone":"bad","value":"4"},{"label":"farmacia, vet…","tone":"warn","value":"14"},{"accent":true,"label":"acierto","value":"94"}],"col_a":"predicho: salud","col_b":"predicho: otro","metric_a":"precisión 0,83","metric_b":"cobertura 0,94","row_a":"real: salud","row_b":"real: otro"}
:::
+ Umbral 0,44 en Jev: pierde 4 clínicas para no dejar pasar 14 negativos difíciles.

## 05 Cuánto deja concluir la muestra

:::diagrama intervalo
alt: Con 8 casos el intervalo de confianza cubre casi todo el rango; con 180 se cierra en torno a 0,72
{"rows":[{"hi":0.98,"label":"8 casos","lo":0.42,"note":"cabe cualquier conclusión","point":0.72},{"accent":true,"hi":0.79,"label":"180 casos","lo":0.647,"note":"0,720","point":0.72}],"ticks":["0,4","0,7","1,0"]}
:::
+ El mismo modelo, la misma pregunta. Lo que cambia es lo que tienes derecho a afirmar.

## 06 El orden en que se pregunta

:::diagrama decisao
alt: Primero se pregunta si existe señal; sin señal se descarta al candidato, con señal se calibra el umbral
{"no":"descarta al candidato","no_label":"no","question":"¿existe señal?","then_a":"la mitad A ajusta","then_b":"la mitad B reporta","yes":"calibra el umbral","yes_label":"sí"}
:::
+ El AUC responde la primera pregunta sin depender de un corte. El corte es la segunda decisión.

:::diagrama fluxo
alt: Un lead de Google Maps pasa por la categoría, el clasificador y un umbral antes de entrar en la campaña
{"branch":{"label":"por debajo del umbral","note":"va a revisión","x":228},"steps":[{"label":"lead de Maps","note":"nombre + categoría"},{"accent":true,"label":"clasificador","note":"noul"},{"label":"p = 0,61","mono":true},{"label":"campaña","note":"umbral 0,44"}]}
:::
+ La categoría carga la señal. El nombre comercial no vale nada para ninguno de los dos.

## 07 Lo que hizo la corrección del prompt

En un segundo caso — separar un mensaje automático de uno escrito por una persona — el clasificador que ya estaba corriendo fallaba casi todo en una sola categoría. Reescribí el prompt apuntando a ella.

:::diagrama antes_depois
alt: El prompt nuevo corrigió la categoría de automático informal de 2 a 25, pero bajó humano informal de 25 a 17
{"from_label":"antiguo","max":25,"rows":[{"from":25,"label":"automático obvio","to":25},{"from":2,"label":"automático informal","to":25,"tone":"good"},{"from":25,"label":"humano informal","to":17,"tone":"bad"},{"from":25,"label":"humano formal","to":25}],"to_label":"nuevo"}
:::
+ Arregló la columna que yo estaba mirando y rompió la que no. De 25 casos cada una.

:::aviso bad Veinte casos escondieron esto
En una muestra de 20, el prompt nuevo marcó 20 de 20. La regresión sólo apareció con 100, porque los cinco casos de humano informal que cayeron en el sorteo fueron justamente los que todavía acertaba.
:::

## 08 Cómo se desarrolló la noche

:::diagrama linha_tempo
alt: La secuencia de pruebas a lo largo de la noche, del primer resultado falso a la prueba de negación
{"events":[{"label":"8 ejemplos","note":"“separación perfecta”","time":"21h","tone":"bad"},{"accent":true,"label":"180 casos","note":"AUC 0,508","time":"23h"},{"accent":true,"label":"prueba de negación","note":"30 segundos","time":"01h"},{"label":"conjunto reservado","note":"regresión","time":"03h"}]}
:::
+ La prueba más barata fue la última que ejecuté.

> La prueba más cara de la noche costó US$ 0,0134. Lo caro fue el tiempo que pasé creyendo en ocho ejemplos.

## 09 Cuál usar

Para composición — negación, número, inferencia — sólo funciona Jev. Para coincidencia léxica los dos entregan, y ahí Laya gana en latencia, coste y privacidad.

El argumento que puede darle la vuelta son los pesos abiertos: Laya es entrenable con tus etiquetas, y Jev no expone nada de fine-tuning. Sólo que entrenar es un proyecto, y sólo se paga si la privacidad o la latencia te empujan a lo local.

:::aviso note Dónde no entra ninguno de los dos
Si ya hay un modelo pequeño y barato haciendo el trabajo, cambiar rara vez paga. La ganancia real suele estar donde no existe ningún clasificador.
:::

:::pergunta
Jev acertó el conteo y el orden de fechas en mis controles, que su propia documentación describe como debilidad. ¿En qué tamaño de lista, y con qué distancia entre fechas, eso deja de valer?
:::

:::origem
Mediciones propias, septiembre de 2026
Conjuntos sintéticos construidos por mí. Todo lo que aparece como número se ejecutó, no se estimó. La latencia es la mediana de 40 llamadas pareadas e intercaladas.
:::
^ Conjuntos sintéticos construidos por mí. Todo lo que aparece como número se ejecutó, no se estimó. La latencia es la mediana de 40 llamadas pareadas e intercaladas.
