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
          class={"dg-node #{if step["accent"], do: "d-fill-a"}"}
          x={i * 150 + 4} y="22" width="126" height="44" rx="8"
        />
        <text class="d-lab" x={i * 150 + 67} y="44" text-anchor="middle"><%= step["label"] %></text>
        <text :if={step["note"]} class="d-labm" x={i * 150 + 67} y="60" text-anchor="middle">
          <%= step["note"] %>
        </text>
        <line :if={i < length(@steps) - 1}
          class="d-edge" x1={i * 150 + 132} y1="44" x2={i * 150 + 148} y2="44"
          marker-end="url(#d-arrow)" />
      <% end %>
    </svg>
    """
  end

  # 02 — how much two groups overlap, drawn as the two densities the AUC
  # summarises. A single number hides whether the overlap is a sliver or a
  # whole shoulder; the curves do not.
  defp distribuicao(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 620 #{length(@rows) * 112 + 12}"} role="img" aria-label={@label}>
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <% base = i * 112 + 84 %>
        <text class="d-labm" x="4" y={i * 112 + 14}><%= row["title"] %></text>
        <line class="d-axis" x1="4" y1={base} x2="520" y2={base} />
        <path class="d-fill-m" d={bell(row["neg_c"], row["neg_s"], base)} />
        <path class="d-fill-a" d={bell(row["pos_c"], row["pos_s"], base)} />
        <text class="d-labm" x={row["neg_c"]} y={base + 16} text-anchor="middle"><%= row["neg"] %></text>
        <text class="d-labm" x={row["pos_c"]} y={base + 16} text-anchor="middle"><%= row["pos"] %></text>
        <text class="d-num" x="540" y={base - 20}><%= row["auc"] %></text>
        <text class="d-labm" x="540" y={base - 4}>AUC</text>
      <% end %>
    </svg>
    """
  end

  # A gaussian sampled into a closed path. Height is fixed so two curves on the
  # same axis compare by position and width, never by area.
  defp bell(center, spread, base) do
    left = round(center - spread * 3)
    right = round(center + spread * 3)

    pts =
      for x <- left..right//4 do
        y = base - 58 * :math.exp(-0.5 * :math.pow((x - center) / spread, 2))
        Integer.to_string(x) <> " " <> Float.to_string(Float.round(y * 1.0, 1))
      end

    "M #{left} #{base} L " <> Enum.join(pts, " L ") <> " L #{right} #{base} Z"
  end

  # 03 — what a change cost. Two columns and an arrow; a row that got worse
  # carries the warning class so the regression reads before the numbers do.
  defp antes_depois(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 480 #{length(@rows) * 34 + 34}"} role="img" aria-label={@label}>
      <text class="d-labm" x="230" y="14" text-anchor="end"><%= @data["from_label"] %></text>
      <text class="d-labm" x="300" y="14"><%= @data["to_label"] %></text>
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <text class="d-lab" x="4" y={i * 34 + 42}><%= row["label"] %></text>
        <text class="d-num" x="230" y={i * 34 + 42} text-anchor="end"><%= row["from"] %></text>
        <line class="d-edge" x1="244" y1={i * 34 + 37} x2="286" y2={i * 34 + 37}
          marker-end="url(#d-arrow)" />
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
      <text class="d-labm" x="150" y="16"><%= @data["col_a"] %></text>
      <text class="d-labm" x="300" y="16"><%= @data["col_b"] %></text>
      <text class="d-labm" x="4" y="72"><%= @data["row_a"] %></text>
      <text class="d-labm" x="4" y="162"><%= @data["row_b"] %></text>
      <%= for {cell, i} <- Enum.with_index(@cells) do %>
        <% col = rem(i, 2)
           row = div(i, 2) %>
        <rect class={"dg-cell #{if cell["accent"], do: "d-fill-a"}"}
          x={140 + col * 150} y={26 + row * 90} width="140" height="80" rx="8" />
        <text class="d-num" style="font-size:22px" x={210 + col * 150} y={66 + row * 90} text-anchor="middle">
          <%= cell["value"] %>
        </text>
        <text class="d-labm" x={210 + col * 150} y={88 + row * 90} text-anchor="middle">
          <%= cell["label"] %>
        </text>
      <% end %>
      <text class="d-num" x="140" y="228"><%= @data["metrics"] %></text>
    </svg>
    """
  end

  # 05 — the order the questions come in. Branch labels sit on the edge, so a
  # reader can follow one path without reading the other.
  defp decisao(assigns) do
    ~H"""
    <svg class="dg" viewBox="0 0 560 180" role="img" aria-label={@label}>
      <rect class="d-node" x="4" y="62" width="160" height="50" rx="8" />
      <text class="d-lab" x="84" y="92" text-anchor="middle"><%= @data["question"] %></text>

      <line class="d-edge" x1="166" y1="80" x2="228" y2="42" marker-end="url(#d-arrow)" />
      <text class="d-labm" x="180" y="52"><%= @data["no_label"] %></text>
      <rect class="d-node" x="232" y="18" width="180" height="46" rx="8" />
      <text class="d-lab" x="322" y="46" text-anchor="middle"><%= @data["no"] %></text>

      <line class="d-edge" x1="166" y1="96" x2="228" y2="134" marker-end="url(#d-arrow)" />
      <text class="d-labm" x="180" y="130"><%= @data["yes_label"] %></text>
      <rect class="d-node d-fill-a" x="232" y="110" width="180" height="46" rx="8" />
      <text class="d-lab" x="322" y="138" text-anchor="middle"><%= @data["yes"] %></text>

      <text :if={@data["footnote"]} class="d-labm" x="428" y="138"><%= @data["footnote"] %></text>
    </svg>
    """
  end

  # 06 — how something unfolded. Time runs down, not across, so a long night
  # does not force a horizontal scroll on a phone.
  defp linha_tempo(assigns) do
    assigns = assign(assigns, :events, assigns.data["events"] || [])

    ~H"""
    <svg class="dg" viewBox={"0 0 520 #{length(@events) * 56 + 16}"} role="img" aria-label={@label}>
      <line class="d-axis" x1="62" y1="8" x2="62" y2={length(@events) * 56 - 20} />
      <%= for {ev, i} <- Enum.with_index(@events) do %>
        <text class="d-num" x="50" y={i * 56 + 28} text-anchor="end"><%= ev["time"] %></text>
        <circle class={"d-dot #{if ev["accent"], do: "d-dot--accent"}"} cx="62" cy={i * 56 + 22} r="5" />
        <text class="d-lab" x="82" y={i * 56 + 20}><%= ev["label"] %></text>
        <text :if={ev["note"]} class="d-labm" x="82" y={i * 56 + 38}><%= ev["note"] %></text>
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
      <line class="d-axis" x1="150" y1={length(@rows) * 64 + 8} x2="540" y2={length(@rows) * 64 + 8} />
      <%= for {t, i} <- Enum.with_index(@data["ticks"] || []) do %>
        <text class="d-labm" x={150 + i * 130} y={length(@rows) * 64 + 26} text-anchor="middle">
          <%= t %>
        </text>
      <% end %>
      <line :if={@data["null_x"]} class="d-axis" stroke-dasharray="3 3" x1={@data["null_x"]} y1="4"
        x2={@data["null_x"]} y2={length(@rows) * 64 + 8} />
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <text class="d-lab" x="4" y={i * 64 + 30}><%= row["label"] %></text>
        <line class={"d-ci #{if row["accent"], do: "d-ci--accent"}"}
          x1={row["lo"]} y1={i * 64 + 25} x2={row["hi"]} y2={i * 64 + 25} />
        <circle class={"d-dot #{if row["accent"], do: "d-dot--accent"}"}
          cx={row["point"]} cy={i * 64 + 25} r="5" />
        <%!-- The note sits under the bar: after it, a wide interval pushes the
              label past the viewBox and the text gets clipped. --%>
        <text class="d-labm" x={row["lo"]} y={i * 64 + 44}><%= row["note"] %></text>
      <% end %>
    </svg>
    """
  end

  defp tone("bad"), do: "d-bad"
  defp tone("good"), do: "d-good"
  defp tone(_), do: ""

  @doc "The arrowhead every form points with. Rendered once per page."
  def defs(assigns) do
    ~H"""
    <svg class="d-defs" aria-hidden="true">
      <defs>
        <marker id="d-arrow" viewBox="0 0 10 10" refX="9" refY="5"
                markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path class="d-arrow" d="M 0 0 L 10 5 L 0 10 z" />
        </marker>
      </defs>
    </svg>
    """
  end
end
