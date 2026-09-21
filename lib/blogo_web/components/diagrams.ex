defmodule BlogoWeb.Diagrams do
  @moduledoc """
  The seven diagram forms, and only these.

  Three rules the whole set obeys, because breaking any one of them breaks a
  theme or a screen size:

    * no colour is written into the SVG — every fill and stroke comes from a
      class, so dark mode is a token swap rather than a second drawing;
    * every figure carries `role` and `aria-label`, since the caption states
      the conclusion and cannot double as the description;
    * the `viewBox` scales with the container, so labels never fall below the
      11.5px floor at phone width.
  """
  use Phoenix.Component

  @doc "Dispatches to a form by name. An unknown form renders nothing."
  attr :form, :string, required: true
  attr :data, :map, required: true
  attr :label, :string, default: ""

  def diagram(%{form: form} = assigns) do
    case form do
      "fluxo" -> fluxo(assigns)
      "distribuicao" -> distribuicao(assigns)
      "antes_depois" -> antes_depois(assigns)
      "matriz" -> matriz(assigns)
      "decisao" -> decisao(assigns)
      "linha_tempo" -> linha_tempo(assigns)
      "intervalo" -> intervalo(assigns)
      _ -> ~H""
    end
  end

  # 01 — where a case travels. The accent marks the step that carries the
  # conclusion, never the whole chain.
  defp fluxo(assigns) do
    assigns = assign(assigns, :steps, assigns.data["steps"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 #{max(length(@steps) * 150, 300)} 92"} role="img" aria-label={@label}>
      <%= for {step, i} <- Enum.with_index(@steps) do %>
        <rect
          class={"dg-node #{if step["accent"], do: "dg-node--accent"}"}
          x={i * 150 + 4} y="22" width="126" height="44" rx="8"
        />
        <text class="dg-label" x={i * 150 + 67} y="44" text-anchor="middle"><%= step["label"] %></text>
        <text :if={step["note"]} class="dg-sub" x={i * 150 + 67} y="60" text-anchor="middle">
          <%= step["note"] %>
        </text>
        <line :if={i < length(@steps) - 1}
          class="dg-edge" x1={i * 150 + 132} y1="44" x2={i * 150 + 148} y2="44"
          marker-end="url(#dg-arrow)" />
      <% end %>
    </svg>
    """
  end

  # 02 — how much two groups overlap. Bands are positioned by rank, not by a
  # numeric scale, so the caption must say the figure is schematic.
  defp distribuicao(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 620 #{length(@rows) * 86 + 10}"} role="img" aria-label={@label}>
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <text class="dg-sub" x="4" y={i * 86 + 16}><%= row["title"] %></text>
        <line class="dg-axis" x1="4" y1={i * 86 + 72} x2="560" y2={i * 86 + 72}
          marker-end="url(#dg-arrow)" />
        <rect class="dg-band" x={row["neg_x"]} y={i * 86 + 30} width={row["neg_w"]} height="30" rx="15" />
        <text class="dg-label" x={row["neg_x"] + div(row["neg_w"], 2)} y={i * 86 + 50} text-anchor="middle">
          <%= row["neg"] %>
        </text>
        <rect class="dg-band dg-band--accent" x={row["pos_x"]} y={i * 86 + 30}
          width={row["pos_w"]} height="30" rx="15" />
        <text class="dg-label" x={row["pos_x"] + div(row["pos_w"], 2)} y={i * 86 + 50} text-anchor="middle">
          <%= row["pos"] %>
        </text>
        <text class="dg-num" x="576" y={i * 86 + 50}><%= row["auc"] %></text>
      <% end %>
    </svg>
    """
  end

  # 03 — what a change cost. Two columns and an arrow; a row that got worse
  # carries the warning class so the regression reads before the numbers do.
  defp antes_depois(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 480 #{length(@rows) * 34 + 34}"} role="img" aria-label={@label}>
      <text class="dg-sub" x="230" y="14" text-anchor="end"><%= @data["from_label"] %></text>
      <text class="dg-sub" x="300" y="14"><%= @data["to_label"] %></text>
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <text class="dg-label" x="4" y={i * 34 + 42}><%= row["label"] %></text>
        <text class="dg-num" x="230" y={i * 34 + 42} text-anchor="end"><%= row["from"] %></text>
        <line class="dg-edge" x1="244" y1={i * 34 + 37} x2="286" y2={i * 34 + 37}
          marker-end="url(#dg-arrow)" />
        <text class={"dg-num #{tone(row["tone"])}"} x="300" y={i * 34 + 42}><%= row["to"] %></text>
      <% end %>
    </svg>
    """
  end

  # 04 — where the error falls. A confusion matrix reads as four cells, and
  # each cell names the mistake rather than just counting it.
  defp matriz(assigns) do
    assigns = assign(assigns, :cells, assigns.data["cells"] || [])

    ~H"""
    <svg class="dg" viewBox="0 0 460 240" role="img" aria-label={@label}>
      <text class="dg-sub" x="150" y="16"><%= @data["col_a"] %></text>
      <text class="dg-sub" x="300" y="16"><%= @data["col_b"] %></text>
      <text class="dg-sub" x="4" y="72"><%= @data["row_a"] %></text>
      <text class="dg-sub" x="4" y="162"><%= @data["row_b"] %></text>
      <%= for {cell, i} <- Enum.with_index(@cells) do %>
        <% col = rem(i, 2)
           row = div(i, 2) %>
        <rect class={"dg-cell #{if cell["accent"], do: "dg-cell--accent"}"}
          x={140 + col * 150} y={26 + row * 90} width="140" height="80" rx="8" />
        <text class="dg-big" x={210 + col * 150} y={66 + row * 90} text-anchor="middle">
          <%= cell["value"] %>
        </text>
        <text class="dg-sub" x={210 + col * 150} y={88 + row * 90} text-anchor="middle">
          <%= cell["label"] %>
        </text>
      <% end %>
      <text class="dg-num" x="140" y="228"><%= @data["metrics"] %></text>
    </svg>
    """
  end

  # 05 — the order the questions come in. Branch labels sit on the edge, so a
  # reader can follow one path without reading the other.
  defp decisao(assigns) do
    ~H"""
    <svg class="dg" viewBox="0 0 560 180" role="img" aria-label={@label}>
      <rect class="dg-node" x="4" y="62" width="160" height="50" rx="8" />
      <text class="dg-label" x="84" y="92" text-anchor="middle"><%= @data["question"] %></text>

      <line class="dg-edge" x1="166" y1="80" x2="228" y2="42" marker-end="url(#dg-arrow)" />
      <text class="dg-sub" x="180" y="52"><%= @data["no_label"] %></text>
      <rect class="dg-node" x="232" y="18" width="180" height="46" rx="8" />
      <text class="dg-label" x="322" y="46" text-anchor="middle"><%= @data["no"] %></text>

      <line class="dg-edge" x1="166" y1="96" x2="228" y2="134" marker-end="url(#dg-arrow)" />
      <text class="dg-sub" x="180" y="130"><%= @data["yes_label"] %></text>
      <rect class="dg-node dg-node--accent" x="232" y="110" width="180" height="46" rx="8" />
      <text class="dg-label" x="322" y="138" text-anchor="middle"><%= @data["yes"] %></text>

      <text :if={@data["footnote"]} class="dg-sub" x="428" y="138"><%= @data["footnote"] %></text>
    </svg>
    """
  end

  # 06 — how something unfolded. Time runs down, not across, so a long night
  # does not force a horizontal scroll on a phone.
  defp linha_tempo(assigns) do
    assigns = assign(assigns, :events, assigns.data["events"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 520 #{length(@events) * 56 + 16}"} role="img" aria-label={@label}>
      <line class="dg-axis" x1="62" y1="8" x2="62" y2={length(@events) * 56 - 20} />
      <%= for {ev, i} <- Enum.with_index(@events) do %>
        <text class="dg-num" x="50" y={i * 56 + 28} text-anchor="end"><%= ev["time"] %></text>
        <circle class={"dg-dot #{if ev["accent"], do: "dg-dot--accent"}"} cx="62" cy={i * 56 + 22} r="5" />
        <text class="dg-label" x="82" y={i * 56 + 20}><%= ev["label"] %></text>
        <text :if={ev["note"]} class="dg-sub" x="82" y={i * 56 + 38}><%= ev["note"] %></text>
      <% end %>
    </svg>
    """
  end

  # 07 — what the sample allows you to conclude. The bar is the confidence
  # interval; a bar that crosses the null line is the whole point of the form.
  defp intervalo(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 560 #{length(@rows) * 64 + 46}"} role="img" aria-label={@label}>
      <line class="dg-axis" x1="150" y1={length(@rows) * 64 + 8} x2="540" y2={length(@rows) * 64 + 8} />
      <%= for {t, i} <- Enum.with_index(@data["ticks"] || []) do %>
        <text class="dg-sub" x={150 + i * 130} y={length(@rows) * 64 + 26} text-anchor="middle">
          <%= t %>
        </text>
      <% end %>
      <line :if={@data["null_x"]} class="dg-null" x1={@data["null_x"]} y1="4"
        x2={@data["null_x"]} y2={length(@rows) * 64 + 8} />
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <text class="dg-label" x="4" y={i * 64 + 30}><%= row["label"] %></text>
        <line class={"dg-ci #{if row["accent"], do: "dg-ci--accent"}"}
          x1={row["lo"]} y1={i * 64 + 25} x2={row["hi"]} y2={i * 64 + 25} />
        <circle class={"dg-dot #{if row["accent"], do: "dg-dot--accent"}"}
          cx={row["point"]} cy={i * 64 + 25} r="5" />
        <%!-- The note sits under the bar: after it, a wide interval pushes the
              label past the viewBox and the text gets clipped. --%>
        <text class="dg-sub" x={row["lo"]} y={i * 64 + 44}><%= row["note"] %></text>
      <% end %>
    </svg>
    """
  end

  defp tone("bad"), do: "dg-num--bad"
  defp tone("good"), do: "dg-num--good"
  defp tone(_), do: ""

  @doc "The arrowhead every form points with. Rendered once per page."
  def defs(assigns) do
    ~H"""
    <svg class="dg-defs" aria-hidden="true">
      <defs>
        <marker id="dg-arrow" viewBox="0 0 10 10" refX="9" refY="5"
                markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path class="dg-arrowhead" d="M 0 0 L 10 5 L 0 10 z" />
        </marker>
      </defs>
    </svg>
    """
  end
end
