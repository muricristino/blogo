defmodule Blogo.Card do
  @moduledoc """
  The image a link to an article shows when it is shared.

  A blog whose stated purpose is for its author's name to be recognised has to
  survive being pasted into LinkedIn, and a link with no image gets a fraction
  of the attention of one with a figure. The article already carries the figure
  that says what it found — the hero diagram — so the card is built from that
  rather than from a stock background nobody looks at twice.

  ## Why the card is drawn as SVG and then rasterised

  Social platforms do not render SVG, so the endpoint must serve PNG. Drawing
  the card as SVG first means the seven diagram forms are reused exactly as the
  site draws them, down to the geometry, instead of being redrawn in a second
  system that would drift. `resvg` turns it into PNG.

  Two consequences worth knowing:

    * **The fonts are carried in `priv/fonts`, not taken from the system.** A
      slim container has no fonts at all, and a missing font here does not warn
      — it renders the card with no text on it.
    * **The stylesheet is inlined with literal values.** `var()` and
      `color-mix()` are resolved by a browser, which is not what is rendering
      this. The values below are the tokens from `app.css`, written out.
  """

  alias BlogoWeb.Diagrams

  # What Facebook, LinkedIn, X and WhatsApp all scale from.
  @width 1200
  @height 630

  # The figure sits beside the title, at the size the seven forms were drawn
  # for — scaling a diagram scales its labels, and 11.5px type does not survive
  # being multiplied.
  @figure_w 470
  @figure_h 150
  @figure_x 660
  @figure_y 230

  @accent "#2563eb"
  @ink "#101828"
  @ink3 "#626c7a"
  @ink4 "#8c95a1"
  @line "#e6ebf3"
  @page "#ffffff"

  @doc """
  Renders the card for a post as PNG.

  Returns `{:ok, binary}`, or `{:error, reason}` when the rasteriser refuses —
  the caller decides what a reader gets instead, and it must not be a crash on
  a page that is otherwise fine.
  """
  def png(post, author) do
    post
    |> svg(author)
    |> Resvg.svg_string_to_png_binary(
      resources_dir: System.tmp_dir!(),
      font_dirs: [font_dir()],
      # The container has no system fonts; relying on them silently produces a
      # card with no text, which looks like a deliberate blank image.
      skip_system_fonts: true
    )
  end

  @doc """
  The card as SVG. Public so a test can read it without rasterising.
  """
  def svg(post, author) do
    lines = wrap(post.title, 21, 4)
    title_top = 178

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#{@accent}" stop-opacity="0.09" />
          <stop offset="0.45" stop-color="#{@page}" stop-opacity="0" />
          <stop offset="1" stop-color="#{@accent}" stop-opacity="0.06" />
        </linearGradient>
        #{arrow_marker()}
      </defs>
      <style>#{stylesheet()}</style>

      <rect width="#{@width}" height="#{@height}" fill="#{@page}" />
      <rect width="#{@width}" height="#{@height}" fill="url(#bg)" />
      <rect y="#{@height - 8}" width="#{@width}" height="8" fill="#{@accent}" />

      #{kicker(post, 72, 96)}
      #{title(lines, 72, title_top)}
      #{figure(post)}
      #{byline(author, 72, @height - 74)}
    </svg>
    """
  end

  # ── the parts ─────────────────────────────────────────────────────────────

  defp kicker(post, x, y) do
    text =
      [post.kind | Enum.take(post.topics || [], 2)]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(" · ")
      |> String.upcase()

    ~s(<text x="#{x}" y="#{y}" font-family="IBM Plex Sans" font-size="21" font-weight="600" letter-spacing="3" fill="#{@accent}">#{escape(text)}</text>)
  end

  defp title(lines, x, top) do
    lines
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {line, i} ->
      ~s(<text x="#{x}" y="#{top + i * 68}" font-family="Newsreader" font-size="58" font-weight="600" fill="#{@ink}">#{escape(line)}</text>)
    end)
  end

  defp byline(author, x, y) do
    """
    <circle cx="#{x + 21}" cy="#{y - 8}" r="21" fill="#{@accent}" fill-opacity="0.12" />
    <text x="#{x + 21}" y="#{y - 2}" text-anchor="middle" font-family="IBM Plex Sans" font-size="16" font-weight="600" fill="#{@accent}">#{escape(initials(author))}</text>
    <text x="#{x + 56}" y="#{y - 2}" font-family="IBM Plex Sans" font-size="24" font-weight="600" fill="#{@ink}">#{escape(author.name)}</text>
    <text x="#{@width - 72}" y="#{y - 2}" text-anchor="end" font-family="IBM Plex Sans" font-size="20" fill="#{@ink4}">#{escape(host())}</text>
    """
  end

  # The hero, drawn by the seven forms exactly as the site draws them, in the
  # right-hand half beside the title.
  #
  # The width and height are written onto the inner `<svg>` because the site
  # sizes it from CSS (`.dg { width: 100% }`), and a rasteriser given neither
  # ignores the viewBox and picks its own scale — which is what put the figure
  # off the bottom of the first card, with its labels at three times the size.
  defp figure(%{hero: %{"form" => form} = hero}) when is_binary(form) do
    # `__changed__: nil` is what lets a function component be called outside a
    # HEEx template: without it `assign/3` refuses, because it cannot tell
    # what changed. Nothing here is re-rendered, so "everything is new" is
    # the right answer.
    inner =
      %{form: form, data: hero["data"] || %{}, label: "", __changed__: nil}
      |> Diagrams.diagram()
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()
      |> String.replace(
        ~s(class="dg" viewBox),
        ~s(class="dg-card" width="#{@figure_w}" height="#{@figure_h}" viewBox)
      )
      |> resolve_tokens()

    ~s|<g transform="translate(#{@figure_x} #{@figure_y})">#{inner}</g>|
  end

  defp figure(_post), do: ""

  # A few figures carry a semantic colour as an inline `style` — the row that
  # went the wrong way, the number that carries the conclusion. Those are
  # written as `var(--bad)`, which a browser resolves and a rasteriser leaves
  # as nothing, so the emphasis silently disappeared from the card while
  # looking correct on the site.
  @tokens %{
    "var(--accent)" => @accent,
    "var(--bad)" => "#be123c",
    "var(--good)" => "#047857",
    "var(--warn)" => "#b45309",
    "var(--ink)" => @ink,
    "var(--ink3)" => @ink3,
    "var(--ink4)" => @ink4,
    "var(--line)" => @line,
    "var(--page-bg)" => @page
  }

  defp resolve_tokens(svg) do
    Enum.reduce(@tokens, svg, fn {token, value}, acc ->
      String.replace(acc, token, value)
    end)
  end

  # ── the stylesheet, resolved ──────────────────────────────────────────────

  # These are the rules from `app.css` with the tokens written out. They are
  # duplicated here on purpose: the browser resolves `var()` and `color-mix()`
  # and the rasteriser does not, so one of the two has to hold literals. A
  # colour that drifts shows up in the card the moment anyone looks at one.
  defp stylesheet do
    """
    .dg-card { fill: #{@page}; stroke: none }
    .d-node { fill: #{@page}; stroke: #{@line}; stroke-width: 1.25 }
    .d-node--a { fill: #{@accent}; fill-opacity: 0.10; stroke: #{@accent}; stroke-width: 1.25 }
    .d-node--m { fill: none; stroke: #{@ink4}; stroke-width: 1.1; stroke-dasharray: 4 4 }
    .d-edge { stroke: #{@ink4}; stroke-width: 1.4; fill: none }
    .d-edge--a { stroke: #{@accent}; stroke-width: 1.6; fill: none }
    .d-lab { fill: #{@ink}; font-size: 13px; font-weight: 500; font-family: 'IBM Plex Sans' }
    .d-labm { fill: #{@ink3}; font-size: 11.5px; font-family: 'IBM Plex Sans' }
    .d-num { fill: #{@ink}; font-size: 12.5px; font-family: 'IBM Plex Sans' }
    .d-arrow { fill: #{@ink4} }
    .d-arrow--a { fill: #{@accent} }
    .d-fill-a { fill: #{@accent}; fill-opacity: 0.22; stroke: #{@accent}; stroke-width: 1.4 }
    .d-fill-m { fill: #64748b; fill-opacity: 0.16; stroke: #94a3b8; stroke-width: 1.4 }
    .d-axis { stroke: #{@line}; stroke-width: 1 }
    .d-dot { fill: #{@ink3} }
    .d-dot--accent { fill: #{@accent} }
    .d-ci { stroke: #{@ink3}; stroke-width: 4; stroke-linecap: round }
    .d-ci--accent { stroke: #{@accent} }
    """
  end

  # The arrowhead lives in the layout's `<defs>` on the site; a standalone SVG
  # carries its own or every arrow loses its head.
  defp arrow_marker do
    ~s(<marker id="d-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path class="d-arrow" d="M0 0 L10 5 L0 10 z" /></marker>)
  end

  # ── text helpers ──────────────────────────────────────────────────────────

  @doc """
  Breaks a title into at most `max_lines` lines of about `per_line` characters.

  SVG has no line breaking, so this is done here. A title that does not fit is
  cut at a word and ends in an ellipsis rather than running off the edge.
  """
  def wrap(text, per_line, max_lines) do
    text
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce([""], fn word, [current | rest] ->
      candidate = String.trim(current <> " " <> word)

      if String.length(candidate) <= per_line and current != "",
        do: [candidate | rest],
        else: if(current == "", do: [word | rest], else: [word, current | rest])
    end)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
    |> case do
      lines when length(lines) <= max_lines ->
        lines

      lines ->
        kept = Enum.take(lines, max_lines)
        List.update_at(kept, -1, &(String.slice(&1, 0, per_line - 1) <> "…"))
    end
  end

  defp initials(author) do
    author.name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp host, do: BlogoWeb.Endpoint.url() |> URI.parse() |> Map.get(:host)

  defp font_dir, do: Application.app_dir(:blogo, "priv/fonts")

  # The title is author-controlled text going into a document, so it is escaped
  # even though nobody but the author writes it.
  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
