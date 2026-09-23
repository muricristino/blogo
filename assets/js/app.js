// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { RichText, Markdown, Grow } from "./editor"
import "./read"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: { RichText, Markdown, Grow },
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket


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
