# blogo — working agreement

## Every task asked for becomes a card in codo, before the work starts

A request that exists only in the conversation is a request nobody can follow
afterwards. Chat scrolls; the board does not. Whoever asked should be able to
see what was picked up, what is in progress and what shipped without having to
ask — and asking is exactly what the board exists to make unnecessary.

So: open the card in `project/blogo` first, then work. It applies to the small
ones too. If it is worth doing, it is worth a line on the board, and a card
that turns out to be two minutes of work costs nothing to have written down.

Move it as the work moves, and close it with the PR — `done` requires one, so
the board can never claim something shipped that nothing can be traced to.

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

## The way in is at /auth/login, and nothing links to it

A reader has no account to sign into, so the public navigation carries no
"Entrar". The blog is public; writing in it is not.

Who may sign in is decided by the environment, the same way codo and webo
decide it:

| | development | with Clerk |
|---|---|---|
| when | no Clerk keys | `CLERK_PUBLISHABLE_KEY` + `CLERK_SECRET_KEY` |
| how | `ADMIN_PASSWORD` | Google, through Clerk |

- **One key without the other is refused at boot.** A half-configured login
  that quietly falls back to the password is a door everyone believes is
  locked.
- **With Clerk configured, the password stops working.** Two doors where one
  was intended means the weaker one decides how strong the entrance is.
- **No password and no Clerk means no way in,** not a way in for everyone. A
  deployment that forgets the variables has an editor nobody can open, which is
  the failure that is safe.
- **`BLOGO_ALLOWED_EMAILS` has the last word over Clerk.** An address removed
  from it stops working on the next request, with no session to hunt down.

**The login happens in the browser and this side only verifies.** Clerk's SDK
signs the person in; the browser posts the session token to `/auth/session`,
which checks it locally — RS256 against the instance's JWKS, plus expiry — and
keeps only the email. The token is never stored server-side. `aud` is
deliberately not validated, because a Clerk session's audience varies by setup;
what authenticates it is the signature against *this* instance plus expiry.
That is the same call codo and webo make, and the tests sign their own tokens
against a generated key rather than needing an instance.

**Guard the request and the socket.** A LiveView reconnects over a websocket,
which never re-runs a plug. `require_admin/2` covers the request and
`on_mount/4` covers the socket; only one of them is a door left open.

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

## The social card renders without a browser

`/imagem/:slug.png` draws the article's hero, its title and the author's name
as a 1200×630 PNG. It is what a link to the blog looks like in a feed, which is
the whole point of a blog written to make its author's name recognisable.

It is drawn as SVG — reusing the same seven forms the site draws — and
rasterised with `resvg`. That buys fidelity and costs two things that fail
quietly:

- **The fonts ship in `priv/fonts` and the rasteriser is told to ignore system
  fonts.** A slim container has none, and a missing font does not warn: it
  renders a card with no text on it. `test/blogo/card_test.exs` asserts the
  files are there.
- **`var()` and `color-mix()` mean nothing outside a browser.** The card
  carries its own stylesheet with the tokens written out, and resolves the
  inline `var(--bad)` a few figures use. A colour that drifts here is invisible
  until someone shares a link.

**Diagram data reaches the renderer unvalidated**, straight from what someone
typed in the editor. Every form has to degrade on incomplete data rather than
raise: a missing number used to raise inside `bell/3` and take down the
article's public page, not just the card.

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

### What the audit sees, and what it does not

`test/mobile_audit.mjs` measures whether a layout **breaks**. A page that never
had any styling does not break, so for weeks it measured `/autor/:slug` — whose
template used seven classes that were not in `app.css` — and reported it clean at
every width. Text with no rule at all does not overflow, does not shrink and is
not too small.

So the audit now also checks that every class in the DOM exists in some loaded
stylesheet. That catches a page the CSS never reached, and it caught one inline
`style` doing what a class was named for. It does not check that the rule does
what the screen needs — only that there is one.

### The audit does not see SVG text

`test/mobile_audit.mjs` measures HTML text nodes. Chart labels are `<text>`
inside an SVG and scale with the viewBox, so a 700-wide chart in a 320px card
renders its 10.5px labels at about four — unreadable, with every check passing.
Charts wide enough to have that problem carry `.ch--wide` and get their text
scaled up under `max-width: 719px`.

## The interface speaks the reader's language; the article speaks its author's

Translating the menu is a table of strings. Translating an article is writing
another article. They are not the same job, so they are not the same feature:
the interface is pt-BR and English through Gettext, and every article stays in
the language it was written in.

- **Detection first, choice above it.** `BlogoWeb.Locale` negotiates
  `accept-language` on every request; a language the reader picked wins over it
  and persists. The two live under two session keys on purpose. Remembering a
  detection as though it had been chosen means a reader who changes their
  browser's language never changes the site again.
- **The request and the socket, the same as the login.** The plug covers the
  request and `on_mount/4` covers the socket, for the reason `require_admin/2`
  and `ensure_admin` both exist: a reconnect runs no plug. Without the hook the
  interface changes language by itself the first time the socket drops. The plug
  writes the negotiated locale into the session precisely because
  `connect_info` carries the session and never the request headers.
- **`<html lang>` is the content's language, not the menu's.**
  `posts.language` says what the article was written in and the article page
  declares that; the nav and the footer carry their own `lang`, and a listing —
  mostly interface — takes the interface's, marking each title. A Portuguese
  essay served as `lang="en"` is a Portuguese essay a search engine indexes as
  English.
- **The address never changes language.** The selector posts to `/idioma` and
  comes back to the same path. `/pt/slug` and `/en/slug` for one text is the
  duplicate content `BlogoWeb.CanonicalHost` spends a 301 to avoid.
- **The msgids are English, so the Portuguese has to be complete.** A string
  nobody translated reaches the Portuguese reader in English, and that is the
  audience the blog already has. `test/blogo_web/locale_test.exs` fails on an
  empty `msgstr` in `pt_BR`, and CI runs `gettext.extract --check-up-to-date` so
  a string added to a template cannot skip extraction. `mix gettext.sync` does
  both halves.
- **`pt_BR` for Gettext, `pt-BR` for markup.** Not interchangeable:
  `Expo.PluralForms` does not know the hyphenated form, so `ngettext` raises
  under it. `BlogoWeb.Locale.tag/1` is the one place that converts.

The editor and the panel are still pt-BR. They are one operator's tools behind
a login, and the reader is who the two languages are for.

## Deployment

The server is a ThinkPad running behind a Cloudflare Tunnel, operated by webo.
Two constraints come from there and are not guessable from this repository:

- **The container serves on port 3000.** The tunnel routes every app to
  `<slug>:3000` and the port is not configurable per project.
- **Migrations run at boot, seeds only on an empty database.** webo owns the
  `.env` and the Postgres container; never edit either by hand.

Read `webo://runbook` through the webo MCP before changing anything about the
server.

Two things about the pipeline itself cost us an outage:

- **`webo-deploy` commits its scaffold back to `main` while it deploys,** and a
  push to `main` is what triggers the deploy. One merge restarted the container
  two or three times until the `Deploy` job learned to skip its own commit. The
  chain was never infinite only because the scaffold usually comes out
  byte-identical, which is luck and not a design.
- **A variable goes in before the code that reads it, never after.**
  `BlogoWeb.CanonicalHost` turns `PHX_HOST` into a **permanent** redirect, so
  deploying it while `PHX_HOST` still held the tunnel's address sent every
  request for the real domain to the old one — with a 301 the browser then
  cached. There is no window small enough to make that safe.
