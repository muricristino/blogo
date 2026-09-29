---
titulo: Fluency is easy to fake
resumo: A skill that teaches across months and treats the student the way I treat a classifier: defining the criterion first, measuring what matters and distrusting whatever feels easy.
endereco: fluency-is-easy-to-fake
tipo: artigo
marcadores: [learning, method, evaluation]
busca: learno sets the winning criterion before the first lesson, measures retention rather than fluency, and compares what the student found easy against what they got right.
---

A friend told me he was doing well in English. He watched series without subtitles, followed meetings, read documentation. Six months later he froze in an interview where he had to *produce* a sentence under pressure, and concluded he had regressed.

He had not regressed. He had never measured the right thing.

> A section the person found easy and scored 55 on is worth more than either fact on its own: it is the gap they cannot see.
> — learno — SKILL.md

**learno** is a skill that teaches one thing across several sessions. It writes the lessons, schedules the reviews, keeps a record of what you have demonstrated and opens each meeting by saying where you are. I went to read what it does expecting a content generator, and found a set of decisions about measurement that I recognised — they are the same ones I use when I evaluate a model.

## 01 A mission that can be lost

The first thing it does is not to teach. It is to refuse.

Before generating any lesson, the skill interviews you until the mission passes two gates: there is a way for both of us to know you have arrived, and this engine can get you there. *Learn English* fails both. *Pass the written driving test* passes. *Solve most LeetCode mediums unaided* passes.

:::diagrama decisao
alt: Can the mission be lost? With no winning criterion nothing is taught; with one, the lesson is generated
{"no":"interview again","no_label":"no","question":"can you lose?","then_a":"criterion written","then_b":"before the content","yes":"generate the first lesson","yes_label":"yes"}
:::
+ A goal you cannot lose is also one you cannot win.
^ **The same labelling rule.** In a test set, writing the criterion first stops it moulding itself to the result. In a lesson, it stops *I studied a lot* from becoming proof that it worked.

That is the labelling rule, applied to people. When I build a test set, I write the criterion before looking at any output — otherwise the criterion moulds itself to the result and I convince myself it went well. Here it is the same: without a target you can miss, *I studied a lot* becomes proof of progress.

## 02 What is measured is not what is felt

The skill separates two things usually treated as one: **fluency** and **storage strength**.

Fluency is managing now. Recognising the word, following the reasoning, understanding the explanation while it happens. It is the sensation of learning — and it is easy to fake, including to yourself, because the material is on the screen and the context does half the work.

Storage strength is managing three weeks from now, without the material in front of you, with the question phrased another way. It is the only one that matters and the one nobody measures, because measuring it is uncomfortable.

:::diagrama antes_depois
alt: Recognising an answer is far easier than producing one; the distance between them is what gets lost
{"from_label":"recognise","max":100,"rows":[{"from":92,"label":"with the material in view","to":61},{"from":78,"label":"three weeks later","to":34,"tone":"bad"}],"to_label":"produce"}
:::
+ The bars are illustrative; the ordering between them is what the literature shows.
^ That is why every lesson demands at least one **recall** — an answer written from scratch. Multiple choice is there for variety, never as a substitute.

The practical consequence is that the skill never accepts recognition as evidence. Every lesson needs at least one free-response section, written from nothing. Multiple-choice quizzes exist to vary the rhythm, and the rule is explicit: they do not substitute, because recognising an answer is easier than producing one.

## 03 The data almost nobody collects

This is the part that made me write the article.

At the end of every lesson the skill asks two things — what confused you, and what felt too easy — and then **crosses the answer with the score**. It is not a satisfaction survey. It is collecting the one piece of data the student has and the system does not.

Finding it easy and doing badly is the blind spot. The person will not ask for help there, because as far as they are concerned it is settled. Finding it hard and doing well is the opposite, and it is not a problem: they already know where to tread carefully.

It is the same reasoning as looking at the confusion matrix instead of the accuracy. The aggregate number says the model is right 87% of the time; the matrix says *which* ones it gets wrong, and that is where you decide whether it is usable. An aggregate lesson score says it went well; the crossing says where it will collapse a month from now.

## 04 The rubric before the answer

When a block of concepts closes, the skill proposes a project. And here comes another decision I did not expect to find:

**The rubric goes in the brief, before the person starts, and they can read it.** Four to six criteria, from a canonical source where one exists. The justification is written down there: so the goalposts cannot be moved after you have seen the answer — and so the person knows what good looks like while there is still time to act on it.

:::pergunta
How many work reviews, code reviews and candidate evaluations have you seen where the criterion was only formulated after the delivery?
:::

And there is a rule about what counts as a delivery that I found the sharpest of the set: **what you hand in is an artefact from the middle of the discipline, never a description of one**. Code that runs, not a document about how you would build it. A demonstration, not a summary of the technique. Something spoken in the language, not a summary of the grammar rule.

The reason is economic: asking for the description tests explanation, and explanation was already tested in the lesson. Asking for it again is writing a long teach-back and calling it a project.

| Discipline | The delivery is | It is not |
| --- | --- | --- |
| Programming | code that runs on the brief's cases | the architecture document |
| Mathematics | a proof, or the counterexample that kills the claim | the explanation of the technique |
| A language | something spoken or written *in* the language | the summary of the rule |
| Philosophy | an argument defended against the strongest objection | the summary of the position |
+ The table exists because the temptation to accept the description is universal.

## 05 When the method is at fault

The last decision is about what to do when the numbers come back bad three times running.

The instruction is to say out loud that **the approach is not working — not that the student is slow**. It is a choice of attribution, and it changes what happens next: if the problem is the student, the way out is to persist; if it is the method, the way out is to change the analogy, split the concept, find another source.

:::diagrama linha_tempo
alt: Three consecutive measurements below seventy-five - the trigger is not to persist, it is to change the approach
{"events":[{"label":"below 75","note":"could be the day","time":"1st"},{"label":"below 75","note":"could be the topic","time":"2nd"},{"accent":true,"label":"below 75","note":"it is the method","time":"3rd"}]}
:::
+ The threshold is declared beforehand, and does not move when it becomes inconvenient.

A teaching system that attributes every failure to the student never has to change. It is comfortable and it is useless — in the same way a classifier evaluated only against easy negatives never has to improve.

:::margem
Mastery has **three sources** with recorded provenance: the conversation, the model validation and the project. And the rule: *never reduce mastery to a score*.
:::

## 06 What I took away

I did not write this to recommend a tool. I wrote it because I found, somewhere I was not looking, the list of decisions about evaluation I had been meaning to write.

Define the criterion before looking at the result. Measure the thing that survives, not the one that pleases. Collect the data the subject has and the system does not, and cross the two. Refuse the description when the thing itself is what matters. And when the measurement comes back bad three times, suspect the instrument before you suspect the object.

It works for teaching someone. It works for evaluating a model. I suspect it works for almost anything where we convince ourselves too quickly that it is going well.

:::origem https://github.com/muricristino/learno
learno — SKILL.md
The quotations come from the skill's own text. The bar numbers in the fluency diagram are illustrative; the ordering between them is what the spaced-repetition literature shows.
:::
^ The quotations come from the skill's own text. The bar numbers in the fluency diagram are illustrative; the ordering between them is what the spaced-repetition literature shows.
