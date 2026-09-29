---
titulo: La fluidez es fácil de fingir
resumo: Una skill que enseña a lo largo de meses y trata al alumno como yo trato a un clasificador: definiendo el criterio antes, midiendo lo que importa y desconfiando de lo que parece fácil.
endereco: la-fluidez-es-facil-de-fingir
tipo: artigo
marcadores: [aprendizaje, método, evaluación]
busca: learno define el criterio de victoria antes de la primera clase, mide retención en vez de fluidez y compara lo que el alumno encontró fácil con lo que acertó.
---

Un amigo me dijo que le iba bien en inglés. Veía series sin subtítulos, seguía reuniones, leía documentación. Seis meses después se quedó en blanco en una entrevista donde tuvo que *producir* una frase bajo presión, y concluyó que había retrocedido.

No había retrocedido. Nunca había medido lo correcto.

> Una sección que la persona encontró fácil y en la que sacó 55 vale más que cualquiera de los dos hechos por separado: es la laguna que no consigue ver.
> — learno — SKILL.md

**learno** es una skill que enseña una cosa a lo largo de varias sesiones. Escribe las clases, programa los repasos, mantiene un registro de lo que has demostrado y abre cada encuentro diciendo dónde estás. Fui a leer lo que hace esperando un generador de contenido, y encontré un conjunto de decisiones sobre medición que reconocí — son las mismas que uso cuando evalúo un modelo.

## 01 Una misión que se puede perder

Lo primero que hace no es enseñar. Es negarse.

Antes de generar ninguna clase, la skill entrevista hasta que la misión pasa dos puertas: existe una manera de que los dos sepamos que llegaste, y este motor puede llevarte hasta allí. *Aprender inglés* falla en las dos. *Aprobar el examen teórico de conducir* pasa. *Resolver la mayoría de los medium de LeetCode sin ayuda* pasa.

:::diagrama decisao
alt: ¿Se puede perder la misión? Sin criterio de victoria no se enseña nada; con criterio, se genera la clase
{"no":"entrevista otra vez","no_label":"no","question":"¿se puede perder?","then_a":"criterio escrito","then_b":"antes del contenido","yes":"genera la primera clase","yes_label":"sí"}
:::
+ Una meta que no se puede perder tampoco se puede ganar.
^ **La misma regla de la etiqueta.** En un conjunto de prueba, escribir el criterio antes impide que se amolde al resultado. En una clase, impide que *estudié mucho* se convierta en prueba de que funcionó.

Esa es la regla de la etiqueta, aplicada a personas. Cuando armo un conjunto de prueba, escribo el criterio antes de mirar ninguna salida — si no, el criterio se amolda al resultado y me convenzo de que salió bien. Aquí es lo mismo: sin un objetivo que se pueda fallar, *estudié mucho* se convierte en prueba de progreso.

## 02 Lo que se mide no es lo que se siente

La skill separa dos cosas que suelen tratarse como una: **fluidez** y **fuerza de almacenamiento**.

La fluidez es poder ahora. Reconocer la palabra, seguir el razonamiento, entender la explicación mientras ocurre. Es la sensación de estar aprendiendo — y es fácil de fingir, incluso ante uno mismo, porque el material está en la pantalla y el contexto hace la mitad del trabajo.

La fuerza de almacenamiento es poder dentro de tres semanas, sin el material a la vista, con la pregunta formulada de otra manera. Es la única que importa y la que nadie mide, porque medirla es incómodo.

:::diagrama antes_depois
alt: Reconocer una respuesta es mucho más fácil que producirla; la distancia entre las dos es lo que se pierde
{"from_label":"reconocer","max":100,"rows":[{"from":92,"label":"con el material a la vista","to":61},{"from":78,"label":"tres semanas después","to":34,"tone":"bad"}],"to_label":"producir"}
:::
+ Las barras son ilustrativas; el orden entre ellas es lo que muestra la literatura.
^ Por eso toda clase exige al menos un **recall** — una respuesta escrita desde cero. La opción múltiple entra para variar, nunca para sustituir.

La consecuencia práctica es que la skill nunca acepta el reconocimiento como evidencia. Toda clase necesita al menos una sección de respuesta libre, escrita desde cero. Los cuestionarios de opción múltiple existen para variar el ritmo, y la regla es explícita: no sustituyen, porque reconocer una respuesta es más fácil que producirla.

## 03 El dato que casi nadie recoge

Esta es la parte que me hizo escribir el artículo.

Al final de cada clase la skill pregunta dos cosas — qué te confundió y qué te pareció demasiado fácil — y entonces **cruza la respuesta con la nota**. No es una encuesta de satisfacción. Es recoger el único dato que tiene el alumno y no tiene el sistema.

Encontrarlo fácil y salir mal es el punto ciego. La persona no va a pedir ayuda ahí, porque para ella eso está resuelto. Encontrarlo difícil y salir bien es lo contrario y no es un problema: ya sabe dónde pisar con cuidado.

Es el mismo razonamiento que mirar la matriz de confusión en vez de la exactitud. El número agregado dice que el modelo acierta el 87%; la matriz dice *cuáles* falla, y ahí se decide si sirve. La nota agregada de una clase dice que fue bien; el cruce dice dónde se va a derrumbar dentro de un mes.

## 04 La rúbrica antes de la respuesta

Cuando cierra un bloque de conceptos, la skill propone un proyecto. Y ahí viene otra decisión que no esperaba encontrar:

**La rúbrica va en el enunciado, antes de que la persona empiece, y puede leerla.** De cuatro a seis criterios, de una fuente canónica cuando existe. La justificación está escrita ahí: para que no se puedan mover los postes después de haber visto la respuesta — y para que la persona sepa qué es bueno mientras todavía hay tiempo de actuar.

:::pergunta
¿Cuántas evaluaciones de trabajo, de código y de candidatos has visto en las que el criterio sólo se formuló después de la entrega?
:::

Y hay una regla sobre qué cuenta como entrega que me pareció la más afilada del conjunto: **lo que se entrega es un artefacto del centro de la disciplina, nunca una descripción de uno**. Código que corre, no un documento sobre cómo lo construirías. Una demostración, no un resumen de la técnica. Algo hablado en el idioma, no un resumen de la regla gramatical.

El motivo es económico: pedir la descripción evalúa la explicación, y la explicación ya se evaluó en la clase. Pedirla otra vez es escribir un teach-back largo y llamarlo proyecto.

| Disciplina | La entrega es | No es |
| --- | --- | --- |
| Programación | código que corre con los casos del enunciado | el documento de arquitectura |
| Matemáticas | una demostración, o el contraejemplo que mata la afirmación | la explicación de la técnica |
| Un idioma | algo hablado o escrito *en* el idioma | el resumen de la regla |
| Filosofía | un argumento defendido contra la objeción más fuerte | el resumen de la posición |
+ La tabla existe porque la tentación de aceptar la descripción es universal.

## 05 Cuando la culpa es del método

La última decisión es sobre qué hacer cuando los números salen mal tres veces seguidas.

La instrucción es decir en voz alta que **el enfoque no está funcionando — no que el alumno es lento**. Es una elección de atribución, y cambia lo que pasa después: si el problema es el alumno, la salida es insistir; si es el método, la salida es cambiar la analogía, dividir el concepto, buscar otra fuente.

:::diagrama linha_tempo
alt: Tres mediciones seguidas por debajo de setenta y cinco - el disparador no es insistir, es cambiar el enfoque
{"events":[{"label":"por debajo de 75","note":"puede ser el día","time":"1ª"},{"label":"por debajo de 75","note":"puede ser el tema","time":"2ª"},{"accent":true,"label":"por debajo de 75","note":"es el método","time":"3ª"}]}
:::
+ El umbral se declara antes, y no se mueve cuando incomoda.

Un sistema de enseñanza que atribuye todo fracaso al alumno nunca necesita cambiar. Es cómodo y es inútil — igual que un clasificador evaluado sólo contra negativos fáciles nunca necesita mejorar.

:::margem
El dominio tiene **tres fuentes** con procedencia registrada: la conversación, la validación por modelo y el proyecto. Y la regla: *nunca reduzcas el dominio a una nota*.
:::

## 06 Lo que me llevé

No escribí esto para recomendar una herramienta. Lo escribí porque encontré, en un sitio donde no buscaba, la lista de decisiones sobre evaluación que quería haber escrito.

Definir el criterio antes de mirar el resultado. Medir lo que sobrevive, no lo que agrada. Recoger el dato que tiene el sujeto y no tiene el sistema, y cruzar los dos. Rechazar la descripción cuando lo que importa es la cosa. Y, cuando la medida sale mal tres veces, sospechar del instrumento antes que del objeto.

Sirve para enseñar a alguien. Sirve para evaluar un modelo. Sospecho que sirve para casi todo aquello en lo que nos convencemos demasiado rápido de que va bien.

:::origem https://github.com/muricristino/learno
learno — SKILL.md
Las citas vienen del propio texto de la skill. Los números de las barras del diagrama de fluidez son ilustrativos; el orden entre ellos es lo que muestra la literatura de repetición espaciada.
:::
^ Las citas vienen del propio texto de la skill. Los números de las barras del diagrama de fluidez son ilustrativos; el orden entre ellos es lo que muestra la literatura de repetición espaciada.
