# Auditoria mobile-first

Verifica, em cada tela e em cada largura a partir de 320px, as regras que o
`CLAUDE.md` define: rolagem horizontal, alvo de toque, tamanho de texto e
medida de linha. E, uma vez por tela, se toda classe usada ali existe no CSS.

```sh
mix phx.server                         # noutro terminal
node test/mobile_audit.mjs             # contra o local
BASE=https://<domínio> node test/mobile_audit.mjs   # contra produção

# As telas do editor pedem senha; sem a variável elas ficam fora da auditoria.
BASE=http://localhost:4000 ADMIN_PASSWORD=<senha> node test/mobile_audit.mjs
```

O Playwright não é dependência deste repositório — ele vem do `node_modules`
de outro projeto, e o caminho está no topo do script. Ajuste se o seu for
outro, ou instale com `npx playwright@latest install chromium`.

**Ao criar uma tela, acrescente-a a `PAGES` no mesmo commit** — ou a
`ADMIN_PAGES`, se ela ficar atrás da senha. Uma tela fora da lista é uma tela
que ninguém verifica.

**Uma opção que muda o desenho de uma tela são duas telas.** A auditoria mede
uma URL, não um estado do banco, então uma chave do painel que troca o layout
pede duas rodadas. A primeira é a figura do card em destaque
(`site.featured_hero`): a home tem de sair limpa com ela ligada e desligada.

```sh
psql -U postgres -d blogo_dev -c "update site set featured_hero = false"
node test/mobile_audit.mjs   # e de novo com true
```

## O que o editor já custou

O editor reaproveita `.bar` e `.card` da página pública, e herdar um sistema de
design herda também as regras que foram escritas para outra tela. Duas
apareceram aqui:

- `.bar .btn { display: none }` existe para tirar o botão "Assinar" da
  navegação do leitor no celular. O editor usa `.bar`, então perdia **Publicar**
  e **Pré-visualizar** exatamente onde eles mais importam — sem aviso nenhum,
  porque um elemento escondido não estoura nada.
- `.field` na folha pública é um campo de 48px de altura fixa. A classe de mesmo
  nome no editor era uma coluna flex, e a altura fixa cortava o último campo do
  painel. O editor passou a usar `.ed-field`.

A lição é a mesma nas duas: **quando uma tela nova reusa uma classe, verifique
o que essa classe já promete em outro lugar.** Renomear é mais barato que
sobrescrever.

## O que cada achado significa

| achado | o que é |
|---|---|
| `scroll-x` | a página inteira rola de lado — sempre um bug |
| `estoura` | um elemento passa da viewport sem um pai que role |
| `alvo` | alvo de toque abaixo de 44px, ou 32px se for link secundário |
| `fonte` | texto de leitura abaixo de 16px |
| `medida` | linha acima de ~75 caracteres |
| `classe sem regra` | a classe está no HTML e não existe em folha nenhuma |

Um elemento dentro de uma caixa com `overflow-x: auto` não é violação: tabela,
código e diagrama rolam dentro de si mesmos por desenho.

## Por que existe a checagem de classe sem regra

As outras cinco medem se o layout **quebra**. Uma página que nunca teve estilo
não quebra: ela passa limpa em todas as larguras. `/autor/:slug` viveu assim
desde o primeiro commit — sete das oito classes do template não existiam no
`app.css`, e a auditoria mediu aquela página por semanas sem ver nada.

A checagem roda só na primeira largura, porque não depende de largura, e compara
o que o HTML usa com o que as folhas carregadas declaram. Ela não sabe se a
regra faz o que a tela precisa; sabe apenas que existe alguma. Uma classe de
gancho para JS, sem estilo por desenho, aparece aqui e deve virar atributo
`data-` em vez de silenciar a checagem.
