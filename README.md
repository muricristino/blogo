# blogo

A blog you host yourself, built so a search for the author's name finds the
author's writing.

Most blog engines treat the byline as a string. blogo treats the author as an
entity: every article points at one stable `schema.org` identity, the author
page carries the profiles that prove the same person owns them, and the pair
is what lets a name search surface the articles rather than the homepage.

Everything renders on the server. The reader gets HTML, no socket, no
hydration — which is the same thing a crawler gets.

## What it does today

**Reading.** An index with a featured article, topic filters and an author
column. Articles in a three-column layout: a table of contents that follows
the reader, the text column, and a margin column where a block's note sits
beside the paragraph it qualifies.

**Writing.** Articles are block lists in `jsonb`, rendered at request time.
A design change re-renders every article; there is no content migration and
no stored HTML.

**Drawing.** Seven diagram forms and no more — flow, distribution, before and
after, matrix, decision, timeline, interval. Each is inline SVG that writes no
literal colour: fills and strokes come from classes, so dark mode is a token
swap rather than a second drawing.

**Being found.** `sitemap.xml`, `robots.txt`, canonical URLs, Open Graph, and
`Article` JSON-LD whose `author` is the same `@id` the author page declares.

**A link to an article carries its figure.** `/imagem/:slug.png` renders the
article's hero diagram, its title and the author's name as a 1200×630 PNG,
drawn from the same seven forms the site uses and rasterised without a browser.
A blog written so that its author's name is recognised has to survive being
pasted into a feed.

## Running it

Needs Elixir 1.18, OTP 27 and PostgreSQL 17.

```sh
mix setup                 # deps, database, migrations, seeds
mix phx.server            # http://localhost:4000
```

`mix setup` seeds one author and six articles so the first run has something
to look at. Edit `priv/repo/seeds.exs` to make it yours, or delete the rows
and write your own.

## How it is put together

```
lib/blogo/content/          Author and Post, and the context around them
lib/blogo_web/components/
  blocks.ex                 the eleven block types an article can hold
  diagrams.ex               the seven diagram forms
  seo.ex                    head tags and structured data
assets/css/app.css          the design system: tokens, then components
```

**One accent.** Surfaces, borders, chips and every diagram derive from
`--accent` through `color-mix`, so changing the brand is one line and there is
no parallel palette to keep in sync.

**Blocks are data.** An article's `body` is `{"blocks": [...]}`. Inline markup
is a deliberately small dialect — `**bold**`, `*italic*`, `` `code` ``,
`[text](url)` — parsed at render rather than stored as HTML, so the database
never holds markup nobody validated.

**One document, two modes.** The editor writes blocks directly in rich mode and
the same document as text in markdown mode. Standard markdown covers five of
the eleven blocks; the other six use a `:::` fence. The conversion is lossless
in both directions and there are tests that say so — a writer who switches
modes mid-article has to find the article they left.

**Public pages are controllers, not LiveView.** Reading is anonymous and
non-interactive; a socket per reader would cost a process and buy nothing.
LiveView is reserved for the editor and the panel.

**A link to an article carries its figure.** `/imagem/:slug.png` renders the
article's hero diagram, its title and the author's name as a 1200×630 PNG,
drawn from the same seven forms the site uses and rasterised without a browser.
A blog written so that its author's name is recognised has to survive being
pasted into a feed.

## Running it

```sh
mix setup
ADMIN_PASSWORD=<uma senha> mix phx.server
```

The blog is public; writing in it is not. The way in is `/auth/login`, and
nothing on the site links to it — a reader has no account to sign into.

With `CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY` set, signing in goes
through Clerk (Google), verified locally against the instance's JWKS;
`BLOGO_ALLOWED_EMAILS` narrows it further and has the last word. Without them,
`ADMIN_PASSWORD` is used instead, which is what a fresh clone gets. One key
without the other is refused at boot, and with neither there is no way in at
all — the failure that is safe. See `deploy/.env.example`.

## Not built yet

Comments and the admin panel. The design for both exists; the code does not.

## Licence

MIT.
