// The editor's browser side: three jobs that cannot be done from the server.
//
//  1. Keep a contenteditable block in sync with the server without ever
//     letting LiveView patch the node the caret is in.
//  2. Turn a selection into the blog's inline dialect (**bold**, *italic*,
//     `code`, [text](url)) and back.
//  3. Open the slash menu when someone types / on an empty line.
//
// The dialect is small on purpose, and the serialiser below only understands
// what it produces. Anything else a browser drops into the node — a pasted
// span, a stray div — is flattened to its text, because storing markup nobody
// validated is how a blog ends up rendering someone else's stylesheet.

const DEBOUNCE = 350

// HTML → the inline dialect. Walks the tree rather than using a regex on
// innerHTML: a regex cannot tell a <b> inside a <code> from one beside it.
function serialize(node) {
  let out = ""

  for (const child of node.childNodes) {
    if (child.nodeType === Node.TEXT_NODE) {
      out += child.nodeValue
      continue
    }

    if (child.nodeType !== Node.ELEMENT_NODE) continue

    const tag = child.tagName.toLowerCase()
    const inner = serialize(child)

    if (tag === "b" || tag === "strong") out += inner ? `**${inner}**` : ""
    else if (tag === "i" || tag === "em") out += inner ? `*${inner}*` : ""
    else if (tag === "code") out += inner ? "`" + inner + "`" : ""
    else if (tag === "a" && child.getAttribute("href")) out += `[${inner}](${child.getAttribute("href")})`
    else if (tag === "br") out += "\n"
    else if (tag === "p" || tag === "div") out += (out === "" ? "" : "\n\n") + inner
    else out += inner
  }

  return out
}

function text(node) {
  return serialize(node)
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]+$/gm, "")
    .trim()
}

// The floating toolbar, created once and moved to whichever block has a
// selection. One node means one place for the caret to be lost, not many.
let bar = null

function toolbar() {
  if (bar) return bar

  bar = document.createElement("div")
  bar.className = "toolbar ed-toolbar"
  bar.hidden = true
  bar.innerHTML = `
    <button type="button" class="tbtn" data-cmd="bold" aria-label="Negrito" style="font-weight:700">B</button>
    <button type="button" class="tbtn" data-cmd="italic" aria-label="Itálico" style="font-style:italic;font-family:Georgia,serif">I</button>
    <button type="button" class="tbtn" data-cmd="code" aria-label="Código embutido">&lt;&gt;</button>
    <button type="button" class="tbtn" data-cmd="link" aria-label="Link">🔗</button>`

  // mousedown, not click: click fires after the selection is already gone.
  bar.addEventListener("mousedown", event => {
    const button = event.target.closest("[data-cmd]")
    if (!button) return
    event.preventDefault()
    apply(button.dataset.cmd)
  })

  document.body.appendChild(bar)
  return bar
}

function apply(cmd) {
  const selection = window.getSelection()
  if (!selection || selection.isCollapsed) return

  if (cmd === "bold") document.execCommand("bold")
  else if (cmd === "italic") document.execCommand("italic")
  else if (cmd === "code") wrapIn("code")
  else if (cmd === "link") {
    const url = window.prompt("Endereço do link")
    if (url) document.execCommand("createLink", false, url)
  }

  const host = selection.anchorNode?.parentElement?.closest("[data-uid]")
  host?.dispatchEvent(new Event("input", { bubbles: true }))
}

// execCommand has no "inline code", so the element is built by hand.
function wrapIn(tag) {
  const selection = window.getSelection()
  const range = selection.getRangeAt(0)
  const element = document.createElement(tag)

  element.appendChild(range.extractContents())
  range.insertNode(element)
  selection.removeAllRanges()
}

function placeToolbar() {
  const selection = window.getSelection()

  // Built on first use inside an editable block, never before. The listener is
  // global, so creating the bar eagerly put it on every page of the site —
  // including the sign-in screen, where it sat in the corner of an empty page.
  const host =
    selection && !selection.isCollapsed && selection.anchorNode
      ? selection.anchorNode.parentElement?.closest(".ed-rt")
      : null

  if (!host) {
    if (bar) bar.hidden = true
    return
  }

  const t = toolbar()

  const rect = selection.getRangeAt(0).getBoundingClientRect()
  t.hidden = false
  t.style.top = `${rect.top + window.scrollY - t.offsetHeight - 8}px`
  t.style.left = `${rect.left + window.scrollX}px`
}

document.addEventListener("selectionchange", placeToolbar)

export const RichText = {
  mounted() {
    this.el.dataset.empty = this.el.textContent.trim() === "" ? "true" : "false"

    this.el.addEventListener("input", () => {
      this.el.dataset.empty = this.el.textContent.trim() === "" ? "true" : "false"

      clearTimeout(this.timer)
      this.timer = setTimeout(() => {
        this.pushEvent("block_input", {
          uid: this.el.dataset.uid,
          field: this.el.dataset.field,
          value: text(this.el)
        })
      }, DEBOUNCE)
    })

    // A slash on an otherwise empty block opens the palette. Anywhere else it
    // is just a slash — a writer typing "km/h" is not asking for a menu.
    this.el.addEventListener("keydown", event => {
      // While the menu is open every key belongs to it: the letters filter,
      // the arrows move, Enter inserts. Without this they fell through into
      // the paragraph, so typing "/h" left an "h" in the text and Enter added
      // a blank line.
      if (this.el.dataset.slashOpen === "true") {
        if (["ArrowDown", "ArrowUp", "Enter", "Escape", "Backspace"].includes(event.key) ||
            event.key.length === 1) {
          event.preventDefault()
          this.pushEvent("slash_key", { key: event.key })
        }
        return
      }

      // Backspace in an empty block removes the block. Without this an emptied
      // paragraph stayed forever as blank lines in the markdown, and the only
      // way out was to find the × in the handle.
      if (event.key === "Backspace" && this.el.textContent.trim() === "") {
        event.preventDefault()
        this.pushEvent("delete_empty", { uid: this.el.dataset.uid })
        return
      }

      if (event.key !== "/" || this.el.dataset.slash !== "true") return
      if (this.el.textContent.trim() !== "") return

      event.preventDefault()
      this.pushEvent("slash", { uid: this.el.dataset.uid })
    })

    // Paste arrives as whatever the source page was. Taking the plain text is
    // what keeps a pasted article from carrying another site's markup in.
    this.el.addEventListener("paste", event => {
      event.preventDefault()
      const plain = event.clipboardData.getData("text/plain")
      document.execCommand("insertText", false, plain)
    })

    const flush = () => {
      clearTimeout(this.timer)
      this.pushEvent("block_input", {
        uid: this.el.dataset.uid,
        field: this.el.dataset.field,
        value: text(this.el)
      })
    }

    this.el.addEventListener("blur", flush)

    // Reloading within the debounce window used to lose the last thing typed.
    this.flushOnLeave = () => { if (this.el.isConnected) flush() }
    window.addEventListener("beforeunload", this.flushOnLeave)
    window.addEventListener("pagehide", this.flushOnLeave)
  },

  destroyed() {
    clearTimeout(this.timer)
    window.removeEventListener("beforeunload", this.flushOnLeave)
    window.removeEventListener("pagehide", this.flushOnLeave)
  }
}

// A block inserted from the palette or the slash menu gets the caret, so the
// writer can type straight away instead of hunting for where it landed.
window.addEventListener("phx:focus_block", event => {
  const target = document.querySelector(`[data-uid="${event.detail.uid}"].ed-rt`)
  if (!target) return

  target.focus()
  const range = document.createRange()
  range.selectNodeContents(target)
  range.collapse(false)
  const selection = window.getSelection()
  selection.removeAllRanges()
  selection.addRange(range)
})

// The markdown pane: a textarea with a line gutter that follows its scroll.
export const Markdown = {
  mounted() {
    this.el.classList.add("mdcode--live")

    this.ghost = document.createElement("pre")
    this.ghost.className = "mdcode mdcode--ghost"
    this.ghost.setAttribute("aria-hidden", "true")
    this.el.parentElement.insertBefore(this.ghost, this.el)

    this.gutter = document.createElement("div")
    this.gutter.className = "gut"
    this.gutter.setAttribute("aria-hidden", "true")
    this.el.parentElement.appendChild(this.gutter)

    const paint = () => {
      const lines = this.el.value.split("\n").length
      this.gutter.textContent = Array.from({ length: lines }, (_, i) => i + 1).join("\n")
      this.ghost.innerHTML = highlight(this.el.value)
      sync()
    }

    const sync = () => {
      this.gutter.scrollTop = this.el.scrollTop
      this.ghost.scrollTop = this.el.scrollTop
      this.ghost.scrollLeft = this.el.scrollLeft
    }

    this.el.addEventListener("scroll", sync)

    this.el.addEventListener("input", () => {
      paint()
      clearTimeout(this.timer)
      this.timer = setTimeout(() => {
        this.pushEvent("markdown_input", { value: this.el.value })
      }, DEBOUNCE)
    })

    // Leaving the field sends immediately. Clicking "Rico" blurs the textarea
    // first, so the last thing typed arrives before the mode changes — without
    // this, anything written inside the debounce window was simply dropped.
    this.el.addEventListener("blur", () => {
      clearTimeout(this.timer)
      this.pushEvent("markdown_input", { value: this.el.value })
    })

    // Tab indents instead of leaving the field: inside a code fence it is the
    // only way to type one.
    this.el.addEventListener("keydown", event => {
      if (event.key !== "Tab") return
      event.preventDefault()
      const { selectionStart: start, selectionEnd: end, value } = this.el
      this.el.value = value.slice(0, start) + "  " + value.slice(end)
      this.el.selectionStart = this.el.selectionEnd = start + 2
      this.el.dispatchEvent(new Event("input"))
    })

    paint()
  },

  destroyed() {
    clearTimeout(this.timer)
    this.gutter?.remove()
    this.ghost?.remove()
  }
}

// A textarea that grows with its content. The title is a textarea rather than
// an input so a long headline wraps instead of scrolling sideways out of view,
// and this is what keeps it from also showing a scrollbar.
export const Grow = {
  mounted() {
    const fit = () => {
      this.el.style.height = "auto"
      this.el.style.height = `${this.el.scrollHeight}px`
    }

    this.el.addEventListener("input", fit)
    fit()
  }
}

// Painting the markdown. Line-based on purpose: the dialect's meaning is
// carried by what a line starts with, so a line is the unit that can be read
// without parsing the document, and a half-typed fence never mis-colours the
// rest of the file.
const ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;" }
const escape = s => s.replace(/[&<>]/g, c => ESCAPES[c])

function highlight(value) {
  let inFront = false
  let inCode = false

  return value
    .split("\n")
    .map((line, i) => {
      const e = escape(line)

      if (line.trim() === "---" && (i === 0 || inFront)) {
        inFront = i === 0
        return `<span class="m-mark">${e}</span>`
      }

      if (inFront) {
        const m = line.match(/^([a-zA-Z_]+):(.*)$/)
        if (m) return `<span class="m-key">${escape(m[1])}:</span><span class="m-str">${escape(m[2])}</span>`
        return e
      }

      if (line.startsWith("```")) {
        inCode = !inCode
        return `<span class="m-dir">${e}</span>`
      }

      if (inCode) return `<span class="m-dim">${e}</span>`
      if (line.startsWith(":::")) return `<span class="m-dir">${e}</span>`
      if (line.startsWith("## ")) return `<span class="m-h">${e}</span>`
      if (line.startsWith("> ")) return `<span class="m-dim">${e}</span>`
      if (line.startsWith("| ")) return `<span class="m-dim">${e}</span>`
      if (line.startsWith("+ ") || line.startsWith("^ "))
        return `<span class="m-mark">${e.slice(0, 1)}</span><span class="m-dim">${e.slice(1)}</span>`

      return e.replace(/\*\*([^*]+)\*\*/g, '<span class="m-h">**$1**</span>')
    })
    .join("\n")
}
