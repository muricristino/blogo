# blogo — working agreement

## Mobile-first is the default, not an adaptation

Design and build for 320px first. A wider screen gets more room through
`min-width` queries; it never gets a different layout bolted on afterwards.

This is a rule because the opposite already cost us. The first version of the
reader was drawn at 1440px and squeezed down, and it shipped with a featured
card that kept two fixed columns on a phone, clipped its own figure, and gave
no scrollbar to say so. Nobody would have found that by resizing a laptop
window.

### What a screen has to satisfy, at every width from 320px up

- **No horizontal page scroll.** `document.scrollWidth` never exceeds
  `clientWidth`. A table, a code block or a diagram may be wider than the
  column — each scrolls inside its own container, never the page.
- **Touch targets are at least 44×44px under `(pointer: coarse)`.** Navigation,
  buttons and icon buttons take the full 44. An inline secondary link — a topic
  tag in a list — may be 32px tall when it has room around it.
- **Reading text is at least 16px on a phone.** Below that, iOS zooms on focus
  and the body copy tires. Labels and captions may go to 11.5px, and no lower.
- **Line length stays under about 70 characters** at every width.
- **Nothing depends on hover.** A hover state may add, never reveal.
- **Content is never clipped to hide an overflow.** `overflow: hidden` on a
  container that cannot fit its content turns a visible bug into an invisible
  one.

### Two mistakes that caused most of the violations

**A grid or flex child defaults to `min-width: auto`,** so it refuses to shrink
below the widest thing it holds — a code block, a long heading, a number set in
40px type. That single default caused the page to overflow in four different
places. Any child of a layout container gets `min-width: 0`.

**An inline `style` beats the stylesheet,** so a media query cannot undo it. The
featured card's two columns and the summary's three were inline, and no
responsive rule could reach them. Layout belongs in a class; inline style is for
a value that genuinely varies per record.

### How to check

`test/mobile_audit.md` documents the Playwright audit. Run it against a screen
before calling it done, and add a screen to it when you build one — the editor
and the panel are denser than anything here, and they inherit this rule.

## Everything written about the code is in English

Commits, pull requests, code, comments, documentation. The exception is content
the reader sees — articles, seeds, interface copy — which follows the reader's
language.

## Comments explain why, not what

A comment earns its place when it says why the code is not the obvious way: a
browser default being worked around, an ordering that looks arbitrary but is
load-bearing, an attribute whose absence fails silently. Someone will otherwise
"fix" it back.

Not worth writing: what the code already says, or the justification for a choice
nobody would question.

## Every published article carries a diagram

A post has a `hero`: one diagram, in the same shape as a body block, stored in
`posts.hero`. It is the figure on the featured card, the mark in the list, and
the article's own image. `Post.changeset/2` rejects a published post without
one — a draft may be incomplete, a published article may not.

The rule exists because the alternative already shipped: the card drew a
hardcoded SVG and the list drew a hardcoded placeholder, so six articles showed
the same two curves and the same grey mark. A figure that is the same for every
article is decoration, and decoration on a card is a lie about what is inside.

- **The hero is one of the seven forms in `BlogoWeb.Diagrams`.** No eighth form,
  no raster image, no literal colour in the SVG.
- **It carries the article's conclusion, not its topic.** `distribuicao` with
  0,956 against 0,508 says what the Laya x Jev piece found; a drawing of two
  robots would not.
- **`alt` is mandatory and states the finding in words,** because the thumbnail
  hides every label — at a sixth of its drawn size the text is noise, so only
  the geometry survives there.
- **It does not repeat in the body.** The card promises a figure and the article
  delivers the same one in its narrative place; rendering it twice reads as a
  templating accident.

## The editor is behind one password

`ADMIN_PASSWORD` guards `/editor`. There is no users table: the blog has one
author, and registration, password reset and roles would be machinery serving
nobody. `BlogoWeb.AdminAuth` is the whole of it, and it is the one module that
gets replaced the day blogo has a second author.

- **No password configured means no way in,** not a way in for everyone. A
  deployment that forgets the variable has an editor nobody can open, which is
  the failure that is safe.
- **Guard the request and the socket.** A LiveView reconnects over a websocket,
  which never re-runs a plug. `require_admin/2` covers the request and
  `on_mount/4` covers the socket; only one of them is a door left open, and
  `test/blogo_web/live/editor_live_test.exs` has a case for exactly that.

## One document, two modes

The editor writes blocks in rich mode and text in markdown mode, and both
produce the same `body["blocks"]`. That only holds while the conversion in
`Blogo.Content.Markdown` is lossless, so it is covered by two separate
properties in `test/blogo/content/markdown_test.exs`:

- **stable** — markdown → blocks → markdown returns the same text. A document
  that changes every time it is saved is unusable.
- **faithful** — blocks → markdown → blocks keeps every block the renderer
  distinguishes.

Adding a block type means adding it to the palette, to the dialect and to both
properties in the same commit. A block that only one mode understands is a
block that the other mode deletes.

## Two rules that came out of watching someone use the editor

**Never write a change into the struct you are about to hand a changeset.**
`Ecto.Changeset.cast/3` compares the attributes against the data; if the data
already carries the change, there is nothing to cast and the column is never
written. The editor did exactly this for its first week: the title updated on
screen, the save badge turned green, and the database never heard about it.
Nothing on screen contradicted it, and 54 tests passed, because not one of them
read the row back after a save.

So: **a test that saves must read the row back from the database.** Asserting
on the rendered HTML, or on the LiveView's own assigns, proves only that the
server agrees with itself.

**A save badge must mean saved.** Every field that can be typed into saves
while it is being typed — `phx-change` on a form with `phx-debounce`, never a
bare `phx-blur` on a loose input. A writer who types a caption and reloads
without clicking elsewhere used to lose it while the screen said "salvo agora".
A silent loss of someone's writing is the worst defect this project can ship.

## A panel may not invent a number

Everything on `/painel` is counted from the `reads` table. Three states look
identical if you are careless, and collapsing them is how a panel starts lying
to the person who trusts it most:

- **not measured** — nothing has been collected, or the figure has no source at
  all. Subscribers is permanently this, because no newsletter exists.
- **measured, nothing happened** — a real zero.
- **measured** — a number.

So `Blogo.Analytics` returns `nil` rather than `0` where there is no
measurement, and the screen says why in words. A delta needs a previous period
to compare against; without one there is no delta, because "+100%" against
nothing is the figure that makes everything else on the screen suspect.

**Two numbers for the same fact have to be the same number.** The depth curve
ends at the completion threshold precisely so its last point *is* the
completion rate. It used to end at literal 100% scroll — touching the footer —
and showed 3% beside a card reading 25%.

**A read is a page view, not a person.** No identifier is stored: no cookie, no
fingerprint, no IP. Nothing can tell whether a hundred reads are a hundred
readers or one reader reloading, so the wording never says "leitores" where it
means "leituras".

### The audit does not see SVG text

`test/mobile_audit.mjs` measures HTML text nodes. Chart labels are `<text>`
inside an SVG and scale with the viewBox, so a 700-wide chart in a 320px card
renders its 10.5px labels at about four — unreadable, with every check passing.
Charts wide enough to have that problem carry `.ch--wide` and get their text
scaled up under `max-width: 719px`.

## Deployment

The server is a ThinkPad running behind a Cloudflare Tunnel, operated by webo.
Two constraints come from there and are not guessable from this repository:

- **The container serves on port 3000.** The tunnel routes every app to
  `<slug>:3000` and the port is not configurable per project.
- **Migrations run at boot, seeds only on an empty database.** webo owns the
  `.env` and the Postgres container; never edit either by hand.

Read `webo://runbook` through the webo MCP before changing anything about the
server.
