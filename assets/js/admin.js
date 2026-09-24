// The editor and the panel: LiveView, the editor's hooks and the sign-in
// loader. Never served to a reader.

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { RichText, Markdown, Grow } from "./editor"

// Só a tela de login carrega isto; nas demais o elemento não existe.
if (document.getElementById("clerk-signin")) import("./auth")

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: { RichText, Markdown, Grow },
  params: { _csrf_token: csrfToken }
})

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket

// The admin surfaces carry the same theme toggle as the public site.
const root = document.documentElement

document.getElementById("theme-toggle")?.addEventListener("click", () => {
  const now = root.getAttribute("data-theme")
  const dark = now ? now === "dark" : matchMedia("(prefers-color-scheme: dark)").matches
  const next = dark ? "light" : "dark"
  root.setAttribute("data-theme", next)
  try { localStorage.setItem("blogo-theme", next) } catch (e) {}
})
