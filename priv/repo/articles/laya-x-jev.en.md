---
titulo: Laya vs Jev: what a typed classifier does, and what it does not
resumo: Two models with the same API and a chasm between them. I measured negation, counting and magnitude on the same cases.
endereco: laya-vs-jev-typed-classifier
tipo: artigo
marcadores: [evaluation, classifiers, method]
busca: A measured comparison of Laya and Jev - AUC 0.956 against 0.508 on hard negatives, a negation test, cost per call and paired latency.
---

@capitular
Two models promise the same thing: instead of generating text, return a typed decision with a probability. **Jev**, from TypeSafe, is a closed API in beta. **Laya** is open weights under Apache-2.0, and runs on your Mac.

I spent a night measuring both on the same cases. The difference is not one of degree.
^ **About the numbers.** Synthetic sets, built by me. Everything here was run, not estimated.

:::numeros
0.956 | Jev's AUC against hard negatives
0.508 | Laya's AUC on the same cases
1.70x | Jev faster, median of 40 paired calls
:::
^ Same cases, same questions, measured on the same night. What separates the two is not top-end accuracy: it is negation, numeric magnitude and counting.

## 01 What each one does

Both expose the same API: you send a state and typed questions, and get probabilities back. Three kinds of question, with the same names in both — `noul` for yes or no, `choice` for picking an option, `score` for ordered levels.

Laya leaves its architecture in plain sight: a bidirectional encoder from the BERT family (`ModernBERT-large` in the English checkpoint, `mmBERT-base` in the multilingual one) with decision heads on top. 421 and 322 million parameters. TypeSafe publishes nothing equivalent about Jev.

|  | Jev 1.13 | Laya multilingual |
| --- | --- | --- |
| Where it runs | TypeSafe's API | your hardware, via MLX |
| Licence | beta, no published terms | Apache-2.0 |
| Parameters | undisclosed | 322M |
| Context window | 32,000 tokens | 1,024 tokens |
| Trainable on your data | no | yes |
| Cost per 1M calls | US$ 13.38 | zero, energy aside |
| Median latency | 295 ms | 26 ms |
+ The last two rows measure different things: one includes the network, the other does not.
^ **Window.** 1,024 tokens sounds small, but none of my cases went past 400.

## 02 The test that separates them in thirty seconds

Before building a set, run negation. It is one line and needs no labels at all.

```bash
# question: "does this person want to cancel the service?"

"i want to cancel my subscription"      laya 0.9912   jev 0.97
"i don't want to cancel, just a doubt"  laya 0.7123   jev 0.04
"no way am i cancelling"                laya 0.9912   jev 0.05
```
+ In Laya, the sentence that negates scores exactly the same as the one that asserts.
^ **Costs nothing.** Six calls, no labels, and it eliminates most candidates.

Laya sees the word *cancel* and decides. That is a bag-of-words signature, and it is enough to rule it out as an intent detector: "don't send me an invoice" and "this isn't urgent" would fire the same way.

The same pattern shows up in counting and in numeric magnitude. With the same words and only the number of items changing, Laya answers "yes" for any list. And between an income of R$ 900 and one of R$ 60,000, it does not move at all.

:::aviso warn The rule that explains both
Laya answers *does this text assert X?* well and *infer X from this text* badly. Sentiment works because the sentence expresses the sentiment. Negation, counting and numeric comparison require composing, and that is where it stops.
:::

## 03 On the set that matters

I built 180 lead-qualification cases, with a rule written down before running anything: a positive is anyone providing healthcare to a human patient by appointment.

Half the negatives are **hard** on purpose — pharmacy, veterinary clinic, gym, aesthetics, health insurance. Everything that smells of health without fitting the rule. That is the population that turns up in a real search.

:::diagrama distribuicao
alt: Jev separates positives from hard negatives with AUC 0.956; in Laya the two groups overlap, with AUC 0.508
{"rows":[{"auc":"0.956","neg":"negatives","neg_c":85,"neg_s":26,"pos":"positives","pos_c":285,"pos_s":28,"title":"Jev — against hard negatives"},{"auc":"0.508","neg":"negatives","neg_c":165,"neg_s":32,"pos":"positives","pos_c":215,"pos_s":32,"title":"Laya — against hard negatives"}]}
:::
+ The curves are schematic; the AUC values are measured. 0.508 is what a coin delivers.
^ **Labelling rule, written first:** treats a human patient, by appointment. Pharmacy, pet shop and gym are out.

Against **easy** negatives — auto parts, grocery, newsstand — Laya scores 0.890. That is why a test built off the top of your head approves it: the negatives that come to mind are always the easy ones.
^ The category with the second highest mean probability in Laya was *health insurance*, which is a negative. A veterinary clinic outranked a dental practice.

## 04 Where the error falls

:::diagrama matriz
alt: Confusion matrix of the lead gate with Jev at threshold 0.44
{"cells":[{"accent":true,"label":"correct","value":"68"},{"label":"clinic lost","tone":"bad","value":"4"},{"label":"pharmacy, vet…","tone":"warn","value":"14"},{"accent":true,"label":"correct","value":"94"}],"col_a":"predicted: health","col_b":"predicted: other","metric_a":"precision 0.83","metric_b":"recall 0.94","row_a":"actual: health","row_b":"actual: other"}
:::
+ Threshold 0.44 on Jev: it loses 4 clinics to keep 14 hard negatives out.

## 05 How much the sample lets you conclude

:::diagrama intervalo
alt: With 8 cases the confidence interval covers almost the whole range; with 180 it closes around 0.72
{"rows":[{"hi":0.98,"label":"8 cases","lo":0.42,"note":"any conclusion fits","point":0.72},{"accent":true,"hi":0.79,"label":"180 cases","lo":0.647,"note":"0.720","point":0.72}],"ticks":["0.4","0.7","1.0"]}
:::
+ The same model, the same question. What changes is what you are entitled to claim.

## 06 The order you ask in

:::diagrama decisao
alt: First you ask whether there is any signal; without signal the candidate is dropped, with signal you calibrate the threshold
{"no":"drop the candidate","no_label":"no","question":"is there signal?","then_a":"half A tunes","then_b":"half B reports","yes":"calibrate the threshold","yes_label":"yes"}
:::
+ AUC answers the first question without depending on a cut. The cut is the second decision.

:::diagrama fluxo
alt: A lead from Google Maps passes through the category, the classifier and a threshold before entering the campaign
{"branch":{"label":"below threshold","note":"goes to review","x":228},"steps":[{"label":"lead from Maps","note":"name + category"},{"accent":true,"label":"classifier","note":"noul"},{"label":"p = 0.61","mono":true},{"label":"campaign","note":"threshold 0.44"}]}
:::
+ The category carries the signal. The trading name is worth nothing to either of them.

## 07 What the prompt fix did

In a second case — separating an automated message from one written by a person — the classifier already running got almost everything wrong in one category. I rewrote the prompt aiming at it.

:::diagrama antes_depois
alt: The new prompt fixed the informal automated category from 2 to 25, but pulled informal human down from 25 to 17
{"from_label":"old","max":25,"rows":[{"from":25,"label":"obvious automated","to":25},{"from":2,"label":"informal automated","to":25,"tone":"good"},{"from":25,"label":"informal human","to":17,"tone":"bad"},{"from":25,"label":"formal human","to":25}],"to_label":"new"}
:::
+ It fixed the column I was looking at and broke the one I was not. Out of 25 cases each.

:::aviso bad Twenty cases hid this
In a sample of 20, the new prompt scored 20 out of 20. The regression only showed up at 100, because the five informal-human cases that made the draw were precisely the ones it still got right.
:::

## 08 How the night unfolded

:::diagrama linha_tempo
alt: The sequence of tests through the night, from the first false result to the negation test
{"events":[{"label":"8 examples","note":"“perfect separation”","time":"9pm","tone":"bad"},{"accent":true,"label":"180 cases","note":"AUC 0.508","time":"11pm"},{"accent":true,"label":"negation test","note":"30 seconds","time":"1am"},{"label":"held-out set","note":"regression","time":"3am"}]}
:::
+ The cheapest test was the last one I ran.

> The most expensive test of the night cost US$ 0.0134. What was expensive was the time I spent believing eight examples.

## 09 Which to use

For composition — negation, number, inference — only Jev works. For lexical matching both deliver, and there Laya wins on latency, cost and privacy.

The argument that can turn it around is open weights: Laya is trainable on your labels, and Jev exposes nothing for fine-tuning. But training is a project, and it only pays off if privacy or latency push you towards running locally.

:::aviso note Where neither belongs
If a small, cheap model is already doing the job, switching rarely pays. The real gain is usually where no classifier exists at all.
:::

:::pergunta
Jev got counting and date ordering right in my controls, which its own documentation describes as a weakness. At what list size, and with what distance between dates, does that stop holding?
:::

:::origem
My own measurements, September 2026
Synthetic sets built by me. Everything that appears as a number was run, not estimated. Latency is the median of 40 paired, interleaved calls.
:::
^ Synthetic sets built by me. Everything that appears as a number was run, not estimated. Latency is the median of 40 paired, interleaved calls.
