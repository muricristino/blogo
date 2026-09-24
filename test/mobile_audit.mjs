import { chromium, devices } from "/Users/murilo/code/axolutions/agrosn/new-belchior/node_modules/playwright/index.mjs"

const BASE = process.env.BASE || "https://ember-pebble-maple.axolutions.com.br"
// Uma tela nova entra aqui no mesmo commit que a cria.
const PAGES = [["/", "índice"], ["/laya-x-jev", "artigo"], ["/sobre", "sobre"], ["/auth/login", "entrada"], ["/tag/avaliacao", "tópico"]]
// O editor exige senha, então entra por aqui antes de ser medido.
const ADMIN = process.env.ADMIN_PASSWORD
const ADMIN_PAGES = ADMIN
  ? [["/painel", "painel"], ["/editor", "lista do editor"], ["/editor/1", "editor"]]
  : []
const WIDTHS = [320, 360, 390, 414, 768]

const audit = (comEstilo) => {
  const out = []
  const doc = document.documentElement

  // 1. rolagem horizontal da página
  if (doc.scrollWidth > doc.clientWidth + 1)
    out.push({ tipo: "scroll-x", detalhe: `${doc.scrollWidth}px em ${doc.clientWidth}px` })

  // 2. qualquer elemento estourando a largura da viewport
  for (const el of document.querySelectorAll("body *")) {
    const r = el.getBoundingClientRect()
    if (r.width === 0) continue
    if (r.right > doc.clientWidth + 1 || r.left < -1) {
      // permitido quando o pai rola sozinho
      let p = el.parentElement, contido = false
      while (p && p !== document.body) {
        if (["auto", "scroll"].includes(getComputedStyle(p).overflowX)) { contido = true; break }
        p = p.parentElement
      }
      if (!contido)
        out.push({ tipo: "estoura", detalhe: `${el.tagName.toLowerCase()}.${el.className?.toString().split(" ")[0] || ""} até ${Math.round(r.right)}px` })
    }
  }

  // 3. alvos de toque
  const toque = matchMedia("(pointer: coarse)").matches
  for (const el of toque ? document.querySelectorAll("a, button, input, [role=button]") : []) {
    const r = el.getBoundingClientRect()
    if (r.width === 0 || r.height === 0) continue

    // Um alvo que ninguém vê não é um alvo de toque. O componente de login do
    // Clerk carrega um <button> escondido só para o Enter submeter o form, e
    // medir a caixa dele acusava um alvo pequeno que não existe para ninguém —
    // nem para leitor de tela.
    const cs = getComputedStyle(el)
    if (cs.visibility === "hidden" || cs.opacity === "0" || el.getAttribute("aria-hidden") === "true")
      continue
    // 44px para navegação e ação; 32px para link secundário em linha.
    const secundario = el.classList.contains("tag")
    const min = secundario ? 32 : 44
    if (r.height < min - 0.5) {
      const txt = (el.textContent || "").trim().slice(0, 24)
      out.push({ tipo: "alvo", detalhe: `${Math.round(r.width)}x${Math.round(r.height)} — "${txt}"` })
    }
  }

  // 4. tamanho de fonte no corpo
  for (const el of document.querySelectorAll(".prose p, .item-dek, .ctext, .cmt-body")) {
    const fs = parseFloat(getComputedStyle(el).fontSize)
    if (fs < 16) out.push({ tipo: "fonte", detalhe: `${fs}px em ${el.className.split(" ")[0]}` })
  }

  // 5. medida de linha
  for (const el of document.querySelectorAll(".prose, .item-dek")) {
    const fs = parseFloat(getComputedStyle(el).fontSize)
    const ch = el.getBoundingClientRect().width / (fs * 0.5)
    if (ch > 75) out.push({ tipo: "medida", detalhe: `~${Math.round(ch)} caracteres em ${el.className.split(" ")[0]}` })
  }

  // 6. ícone espremido: um SVG que declara largura e é desenhado menor
  //
  // As checagens acima medem estouro, e um filho de flex cede espaço em vez de
  // transbordar — o logo do cabeçalho foi desenhado com 3px de largura a 320px
  // sem nada rolar para o lado. O que se afirma aqui é que um ícone com tamanho
  // declarado tem o tamanho que declarou.
  for (const el of document.querySelectorAll("svg[width]")) {
    const querido = parseFloat(el.getAttribute("width"))
    const real = el.getBoundingClientRect().width
    if (querido > 0 && real < querido - 1) {
      const onde = el.parentElement?.className?.toString().split(" ")[0] || el.parentElement?.tagName?.toLowerCase()
      out.push({ tipo: "ícone espremido", detalhe: `${Math.round(real)}px onde pede ${querido}px, em .${onde}` })
    }
  }

  // 7. classe sem regra — só na primeira largura, porque não depende dela
  //
  // As checagens acima medem se o layout quebra. Nenhuma delas vê uma página
  // que nunca teve estilo: /autor/:slug usava sete classes que não existiam no
  // CSS e passava limpa em todas as larguras, por semanas, porque texto sem
  // regra nenhuma não estoura, não encolhe e não fica pequeno demais.
  if (comEstilo) {
    const declaradas = new Set()
    const varrer = regras => {
      for (const r of regras) {
        if (r.selectorText)
          for (const m of r.selectorText.matchAll(/\.(-?[_a-zA-Z][-\w]*)/g)) declaradas.add(m[1])
        if (r.cssRules) varrer(r.cssRules)
      }
    }
    // Uma folha de outra origem recusa .cssRules; nenhuma delas declara classe nossa.
    for (const f of document.styleSheets) { try { varrer(f.cssRules) } catch {} }

    // O LiveView põe as suas próprias classes de estado no <html> e nos
    // formulários; não são nossas para estilizar.
    const orfas = new Map()
    for (const el of document.querySelectorAll("body *"))
      for (const c of el.classList)
        if (!declaradas.has(c) && !c.startsWith("phx-")) orfas.set(c, (orfas.get(c) || 0) + 1)
    for (const [c, n] of orfas) out.push({ tipo: "classe sem regra", detalhe: `.${c} (${n}x)` })
  }

  const resumo = {}
  for (const v of out) (resumo[v.tipo] ||= []).push(v.detalhe)
  return resumo
}

const b = await chromium.launch()
for (const [path, nome] of [...PAGES, ...ADMIN_PAGES]) {
  const privada = ADMIN_PAGES.some(([p]) => p === path)
  console.log(`\n### ${nome}  ${path}`)
  for (const w of WIDTHS) {
    const p = await b.newPage({ viewport: { width: w, height: 800 }, deviceScaleFactor: 2, isMobile: w < 500, hasTouch: w < 500 })
    if (privada) {
      await p.goto(BASE + "/auth/login")

      // Com o Clerk configurado a senha não é uma segunda porta, então não há
      // como esta auditoria entrar sozinha. Melhor dizer isso do que travar
      // num formulário que não existe.
      const temSenha = await p.locator("form.auth-form input[name=password]").count()
      if (!temSenha) {
        console.log(`  ${w}px  — pulada (servidor em modo Clerk; use um servidor sem chaves)`)
        await p.close()
        continue
      }

      await p.fill("form.auth-form input[name=password]", ADMIN)
      await p.click("form.auth-form button[type=submit]")
      await p.waitForURL(url => !url.pathname.startsWith("/auth/"))
    }
    await p.goto(BASE + path, { waitUntil: "networkidle" })
    await p.waitForTimeout(400)
    const r = await p.evaluate(audit, w === WIDTHS[0])
    const tipos = Object.keys(r)
    if (!tipos.length) console.log(`  ${w}px  ✓ limpo`)
    else for (const t of tipos) {
      const u = [...new Set(r[t])]
      console.log(`  ${w}px  ✗ ${t} (${r[t].length})`)
      u.slice(0, 3).forEach(d => console.log(`          ${d}`))
      if (u.length > 3) console.log(`          … e mais ${u.length - 3}`)
    }
    await p.close()
  }
}
await b.close()
