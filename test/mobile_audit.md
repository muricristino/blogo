# Auditoria mobile-first

Verifica, em cada tela e em cada largura a partir de 320px, as regras que o
`CLAUDE.md` define: rolagem horizontal, alvo de toque, tamanho de texto e
medida de linha.

```sh
mix phx.server                         # noutro terminal
node test/mobile_audit.mjs             # contra o local
BASE=https://<domínio> node test/mobile_audit.mjs   # contra produção
```

O Playwright não é dependência deste repositório — ele vem do `node_modules`
de outro projeto, e o caminho está no topo do script. Ajuste se o seu for
outro, ou instale com `npx playwright@latest install chromium`.

**Ao criar uma tela, acrescente-a a `PAGES` no mesmo commit.** Uma tela fora
da lista é uma tela que ninguém verifica.

## O que cada achado significa

| achado | o que é |
|---|---|
| `scroll-x` | a página inteira rola de lado — sempre um bug |
| `estoura` | um elemento passa da viewport sem um pai que role |
| `alvo` | alvo de toque abaixo de 44px, ou 32px se for link secundário |
| `fonte` | texto de leitura abaixo de 16px |
| `medida` | linha acima de ~75 caracteres |

Um elemento dentro de uma caixa com `overflow-x: auto` não é violação: tabela,
código e diagrama rolam dentro de si mesmos por desenho.
