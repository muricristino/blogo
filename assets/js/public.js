// What a reader's browser needs, and nothing else.
//
// This used to be one bundle with LiveView, the editor hooks and the Clerk
// loader inside it — 158KB on an article page that has no LiveView element on
// it at all. A reader paid for the editor's dependencies on every page view,
// and Core Web Vitals is a ranking factor.

import "./read"

// Theme toggle and reading progress. Both are per-viewer conveniences, so a
// blocked localStorage degrades to "follow the system" rather than failing.
const root = document.documentElement

document.getElementById("theme-toggle")?.addEventListener("click", () => {
  const now = root.getAttribute("data-theme")
  const dark = now ? now === "dark" : matchMedia("(prefers-color-scheme: dark)").matches
  const next = dark ? "light" : "dark"
  root.setAttribute("data-theme", next)
  try { localStorage.setItem("blogo-theme", next) } catch (e) {}
})

const rail = document.getElementById("read-rail")
if (rail) {
  const paint = () => {
    const max = document.body.scrollHeight - innerHeight
    rail.style.width = (max > 0 ? Math.min(100, (scrollY / max) * 100) : 0) + "%"
  }
  addEventListener("scroll", paint, { passive: true })
  addEventListener("resize", paint)
  paint()
}

// Percentage and minutes left, and the table of contents following the reader.
// Both read from the same scroll position the rail already tracks.
const pct = document.getElementById("read-pct")
const left = document.getElementById("read-left")
const tocLinks = [...document.querySelectorAll("[data-toc]")]
const total = left ? Number(left.textContent) : 0

if (pct || tocLinks.length) {
  const update = () => {
    const max = document.body.scrollHeight - innerHeight
    const p = max > 0 ? Math.min(1, Math.max(0, scrollY / max)) : 0
    if (pct) pct.textContent = Math.round(p * 100) + "%"
    if (left) left.textContent = Math.max(0, Math.ceil(total * (1 - p)))

    let current = tocLinks[0]
    for (const a of tocLinks) {
      const el = document.getElementById(a.dataset.toc)
      if (el && el.getBoundingClientRect().top <= 120) current = a
    }
    tocLinks.forEach(a => a.classList.toggle("is-active", a === current))
  }
  addEventListener("scroll", update, { passive: true })
  addEventListener("resize", update)
  update()
}

// Copy button on code blocks, which only exist on an article.
document.querySelectorAll("[data-copy]").forEach(btn => {
  btn.addEventListener("click", () => {
    const code = btn.closest(".code")?.querySelector("code")?.textContent
    if (!code) return
    navigator.clipboard?.writeText(code).then(() => {
      const was = btn.textContent
      btn.textContent = "copiado"
      setTimeout(() => (btn.textContent = was), 1500)
    }).catch(() => {})
  })
})
