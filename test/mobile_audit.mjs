import { chromium, devices } from "/Users/murilo/code/axolutions/agrosn/new-belchior/node_modules/playwright/index.mjs"

const BASE = process.env.BASE || "https://ember-pebble-maple.axolutions.com.br"
// Uma tela nova entra aqui no mesmo commit que a cria.
const PAGES = [["/", "índice"], ["/laya-x-jev", "artigo"], ["/autor/muri-cristino", "autor"], ["/auth/login", "entrada"], ["/serie/avaliar-sem-se-enganar", "série"], ["/tag/avaliacao", "tópico"]]
// O editor exige senha, então entra por aqui antes de ser medido.
const ADMIN = process.env.ADMIN_PASSWORD
const ADMIN_PAGES = ADMIN
  ? [["/painel", "painel"], ["/editor", "lista do editor"], ["/editor/1", "editor"]]
  : []
const WIDTHS = [320, 360, 390, 414, 768]

const audit = () => {
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
    const r = await p.evaluate(audit)
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
