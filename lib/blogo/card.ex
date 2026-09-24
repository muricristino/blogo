defmodule Blogo.Card do
  @moduledoc """
  The 1200×630 PNG a link to an article shows when it is shared.

  Composed as SVG so the seven diagram forms are reused exactly as the site
  draws them, then rasterised with `resvg` — social platforms do not render
  SVG. Two things fail silently outside a browser:

    * fonts come from `priv/fonts` and system fonts are skipped, because a slim
      container has none and a missing font renders a card with no text;
    * `var()` and `color-mix()` mean nothing to a rasteriser, so the stylesheet
      below holds the `app.css` tokens written out.
  """

  alias BlogoWeb.Diagrams

  @width 1200
  @height 630

  # Drawn at the size the forms were designed for: scaling a diagram scales its
  # labels, and 11.5px type does not survive being multiplied.
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
  Renders the card as PNG, or `{:error, reason}` when the rasteriser refuses —
  a card that fails to draw must not take the article's page with it.
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

  @doc "The card as SVG, so a test can read it without rasterising."
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

  # Width and height go onto the inner `<svg>` because the site sizes it from
  # CSS; a rasteriser given neither ignores the viewBox and picks its own
  # scale. `__changed__: nil` is what lets a function component be called
  # outside a HEEx template.
  defp figure(%{hero: %{"form" => form} = hero}) when is_binary(form) do
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

  # Figures carry semantic colour as an inline `var(--bad)`, which a rasteriser
  # leaves as nothing — the emphasis vanished from the card while looking right
  # on the site.
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

  # `app.css` with the tokens written out. Duplicated on purpose: one of the two
  # has to hold literals, and it cannot be the browser's copy.
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

  # On the site the arrowhead lives in the layout's `<defs>`.
  defp arrow_marker do
    ~s(<marker id="d-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path class="d-arrow" d="M0 0 L10 5 L0 10 z" /></marker>)
  end

  # ── text helpers ──────────────────────────────────────────────────────────

  @doc """
  Breaks a title into at most `max_lines` lines — SVG has no line breaking. A
  title that still does not fit is cut at a word and ellipsised.
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

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
