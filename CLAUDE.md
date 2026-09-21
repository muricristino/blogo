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

## Deployment

The server is a ThinkPad running behind a Cloudflare Tunnel, operated by webo.
Two constraints come from there and are not guessable from this repository:

- **The container serves on port 3000.** The tunnel routes every app to
  `<slug>:3000` and the port is not configurable per project.
- **Migrations run at boot, seeds only on an empty database.** webo owns the
  `.env` and the Postgres container; never edit either by hand.

Read `webo://runbook` through the webo MCP before changing anything about the
server.
