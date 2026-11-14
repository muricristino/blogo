defmodule BlogoWeb.Diagrams do
  @moduledoc """
  The seven diagram forms, and only these. Geometry and class names come from
  the canvas, so a figure drawn here is the figure that was designed.

  Three rules the set obeys: no colour is written into the SVG, so dark mode is
  a token swap rather than a second drawing; every figure carries `role` and
  `aria-label`, because the caption states the conclusion and cannot double as
  the description; and the accent marks the one element carrying that
  conclusion.
  """
  use Phoenix.Component

  attr :form, :string, required: true
  attr :data, :map, required: true
  attr :label, :string, default: ""
  attr :orientation, :string, default: "h", doc: "\"v\" stacks a flow into a column"

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

  @flow_h 42
  @flow_gap 20
  @flow_width 470
  @flow_v_gap 22
  @flow_v_width 200
  @flow_v_min 150

  # 01 — where a case travels. The dashed branch is always the unwanted path.
  #
  # Boxes are as wide as their words: an even split of the width put "Street
  # View" across the border of an 80px box. The height is only what is drawn,
  # because a fixed 150 left a blank band under every flow without a branch.
  defp fluxo(%{orientation: "v"} = assigns) do
    steps = flow_boxes(assigns.data["steps"])
    box_w = steps |> Enum.map(& &1.w) |> Enum.max(fn -> 0 end) |> max(@flow_v_min)
    width = max(box_w + 2, @flow_v_width)
    x = div(width - box_w, 2)
    height = max(length(steps) * (@flow_h + @flow_v_gap) - @flow_v_gap + 2, @flow_h)

    assigns =
      assign(assigns,
        steps: Enum.with_index(steps),
        box_w: box_w,
        x: x,
        width: width,
        height: height,
        last: length(steps) - 1,
        flow_h: @flow_h,
        flow_v_gap: @flow_v_gap
      )

    ~H"""
    <svg class="dg dg--v" viewBox={"0 0 #{@width} #{@height}"} role="img" aria-label={@label}>
      <%= for {step, i} <- @steps do %>
        <% y = 1 + i * (@flow_h + @flow_v_gap) %>
        <rect
          class={["d-node", step.accent && "d-node--a"]}
          x={@x}
          y={y}
          width={@box_w}
          height={@flow_h}
          rx="10"
        />
        <text
          class={if step.mono, do: "d-num", else: "d-lab"}
          x={@x + div(@box_w, 2)}
          y={if step.note, do: y + 18, else: y + 25}
          text-anchor="middle"
        >
          {step.label}
        </text>
        <text :if={step.note} class="d-labm" x={@x + div(@box_w, 2)} y={y + 33} text-anchor="middle">
          {step.note}
        </text>
        <line
          :if={i < @last}
          class="d-edge"
          x1={div(@width, 2)}
          y1={y + @flow_h + 2}
          x2={div(@width, 2)}
          y2={y + @flow_h + @flow_v_gap - 4}
          marker-end="url(#d-arrow)"
        />
      <% end %>
    </svg>
    """
  end

  defp fluxo(assigns) do
    steps = flow_boxes(assigns.data["steps"])
    branch = flow_branch(assigns.data["branch"])
    drawn = Enum.sum(Enum.map(steps, & &1.w)) + @flow_gap * max(length(steps) - 1, 0)
    width = max(drawn, @flow_width)
    top = if branch, do: 26, else: 1

    xs =
      steps
      |> Enum.scan(div(width - drawn, 2) - @flow_gap, fn step, prev_end ->
        prev_end + @flow_gap + step.w
      end)
      |> Enum.zip(steps)
      |> Enum.map(fn {right, step} -> right - step.w end)

    assigns =
      assign(assigns,
        steps: Enum.zip([steps, xs, 0..max(length(steps) - 1, 0)]),
        branch: branch,
        width: width,
        top: top,
        height: if(branch, do: 150, else: @flow_h + 2),
        last: length(steps) - 1,
        flow_h: @flow_h,
        flow_gap: @flow_gap
      )

    ~H"""
    <svg class="dg dg--h" viewBox={"0 0 #{@width} #{@height}"} role="img" aria-label={@label}>
      <%= for {step, x, i} <- @steps do %>
        <rect
          class={["d-node", step.accent && "d-node--a"]}
          x={x}
          y={@top}
          width={step.w}
          height={@flow_h}
          rx="10"
        />
        <text
          class={if step.mono, do: "d-num", else: "d-lab"}
          x={x + div(step.w, 2)}
          y={if step.note, do: @top + 18, else: @top + 25}
          text-anchor="middle"
        >
          {step.label}
        </text>
        <text :if={step.note} class="d-labm" x={x + div(step.w, 2)} y={@top + 33} text-anchor="middle">
          {step.note}
        </text>
        <line
          :if={i < @last}
          class="d-edge"
          x1={x + step.w + 2}
          y1={@top + div(@flow_h, 2)}
          x2={x + step.w + @flow_gap - 2}
          y2={@top + div(@flow_h, 2)}
          marker-end="url(#d-arrow)"
        />
      <% end %>

      <%= if @branch do %>
        <path
          class="d-edge"
          d={"M#{@branch.x} 66 L#{@branch.x} 104"}
          stroke-dasharray="4 4"
          marker-end="url(#d-arrow)"
        />
        <rect class="d-node d-node--m" x={@branch.x - 70} y="108" width="140" height="32" rx="10" />
        <text class="d-labm" x={@branch.x} y="128" text-anchor="middle">{@branch.label}</text>
        <text :if={@branch.note} class="d-labm" x={@branch.x + 80} y="128">
          {@branch.note}
        </text>
      <% end %>
    </svg>
    """
  end

  @doc """
  Whether a flow is drawn better as a column on a narrow screen: a row of
  boxes scaled into a phone's width shrinks its labels below reading size.
  A branch is positioned in the row's own coordinates, so a flow with one keeps
  its row.
  """
  def flow_stacks?(%{"steps" => steps} = data) when is_list(steps),
    do: length(steps) > 2 and is_nil(data["branch"])

  def flow_stacks?(_), do: false

  defp flow_boxes(steps) when is_list(steps) do
    steps
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn step ->
      label = text_of(step["label"])
      note = if step["note"] in [nil, ""], do: nil, else: text_of(step["note"])
      mono = step["mono"] == true
      label_w = text_width(label, if(mono, do: 7.6, else: 6.8))
      note_w = if note, do: text_width(note, 5.7), else: 0

      %{
        label: label,
        note: note,
        mono: mono,
        accent: step["accent"] == true,
        w: max(round(max(label_w, note_w)) + 24, 64)
      }
    end)
  end

  defp flow_boxes(_), do: []

  defp flow_branch(%{"x" => x} = branch) when is_number(x),
    do: %{x: x, label: text_of(branch["label"]), note: branch["note"]}

  defp flow_branch(_), do: nil

  defp text_of(nil), do: ""
  defp text_of(v), do: to_string(v)

  # No font metrics outside a browser, and the card is rasterised without one.
  # An average advance per character, measured on IBM Plex Sans at the sizes
  # the classes set, errs a little wide, which costs padding rather than a
  # label crossing its border.
  defp text_width(text, per_char), do: String.length(text) * per_char

  # 02 — how much two groups overlap: the densities behind a single AUC.
  defp distribuicao(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox="0 0 470 150" role="img" aria-label={@label}>
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <% base = i * 74 + 62 %>
        <text class="d-labm" x="0" y={base - 48}>{row["title"]}</text>
        <line class="d-axis" x1="0" y1={base} x2="386" y2={base} />
        <path class="d-fill-m" d={bell(row["neg_c"], row["neg_s"], base)} />
        <path class="d-fill-a" d={bell(row["pos_c"], row["pos_s"], base)} />
        <text class="d-num" x="400" y={base - 6} style={i > 0 && "fill: var(--accent);"}>
          {row["auc"]}
        </text>
      <% end %>
    </svg>
    """
  end

  # 03 — what a change cost. Two bars per row, never three; only rows that
  # moved take a semantic colour.
  defp antes_depois(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox="0 0 470 150" role="img" aria-label={@label}>
      <text class="d-labm" x="0" y="10">{@data["from_label"]}</text>
      <text class="d-labm" x="150" y="10">{@data["to_label"]}</text>
      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <% y = i * 34 + 20
        max = @data["max"] || 25 %>
        <rect class="d-fill-m" x="0" y={y} width={bar(row["from"], max)} height="12" rx="6" />
        <rect class="d-fill-a" x="150" y={y} width={bar(row["to"], max)} height="12" rx="6" />
        <text class="d-labm" x="278" y={y + 10} style={tone_style(row["tone"])}>
          {row["label"]} · {row["from"]} → {row["to"]}
        </text>
      <% end %>
    </svg>
    """
  end

  # 04 — where the error falls. Each cell names the mistake: a count alone does
  # not say which error you can afford.
  defp matriz(assigns) do
    assigns = assign(assigns, :cells, assigns.data["cells"] || [])

    ~H"""
    <svg class="dg" viewBox="0 0 470 150" role="img" aria-label={@label}>
      <text class="d-labm" x="112" y="10">{@data["col_a"]}</text>
      <text class="d-labm" x="252" y="10">{@data["col_b"]}</text>
      <text class="d-labm" x="0" y="48">{@data["row_a"]}</text>
      <text class="d-labm" x="0" y="112">{@data["row_b"]}</text>

      <%= for {cell, i} <- Enum.with_index(@cells) do %>
        <% x = 108 + rem(i, 2) * 140
        y = 20 + div(i, 2) * 64 %>
        <rect
          class={["d-node", cell["accent"] && "d-node--a"]}
          x={x}
          y={y}
          width="130"
          height="54"
          rx="10"
        />
        <text
          class="d-num"
          x={x + 65}
          y={y + 25}
          text-anchor="middle"
          style={tone_style(cell["tone"])}
        >
          {cell["value"]}
        </text>
        <text class="d-labm" x={x + 65} y={y + 42} text-anchor="middle">{cell["label"]}</text>
      <% end %>

      <text :if={@data["metric_a"]} class="d-labm" x="392" y="52">{@data["metric_a"]}</text>
      <text :if={@data["metric_b"]} class="d-labm" x="392" y="116">{@data["metric_b"]}</text>
    </svg>
    """
  end

  # 05 — the order the questions come in. Two levels at most; a third is a list,
  # and a list should be written as one.
  defp decisao(assigns) do
    ~H"""
    <svg class="dg" viewBox="0 0 470 160" role="img" aria-label={@label}>
      <rect class="d-node d-node--a" x="0" y="58" width="132" height="38" rx="10" />
      <text class="d-lab" x="66" y="82" text-anchor="middle">{@data["question"]}</text>

      <path class="d-edge" d="M134 70 C 170 70 170 26 196 26" marker-end="url(#d-arrow)" />
      <text class="d-labm" x="146" y="42">{@data["no_label"]}</text>
      <rect class="d-node d-node--m" x="200" y="8" width="150" height="36" rx="10" />
      <text class="d-labm" x="275" y="31" text-anchor="middle">{@data["no"]}</text>

      <path class="d-edge" d="M134 84 C 170 84 170 118 196 118" marker-end="url(#d-arrow)" />
      <text class="d-labm" x="146" y="116">{@data["yes_label"]}</text>
      <rect class="d-node" x="200" y="100" width="150" height="36" rx="10" />
      <text class="d-lab" x="275" y="123" text-anchor="middle">{@data["yes"]}</text>

      <line
        :if={@data["then_a"]}
        class="d-edge"
        x1="352"
        y1="118"
        x2="380"
        y2="118"
        marker-end="url(#d-arrow)"
      />
      <text :if={@data["then_a"]} class="d-labm" x="386" y="114">{@data["then_a"]}</text>
      <text :if={@data["then_b"]} class="d-labm" x="386" y="130">{@data["then_b"]}</text>
    </svg>
    """
  end

  # 06 — how something unfolded: what happened above the line, what it meant
  # below.
  defp linha_tempo(assigns) do
    assigns = assign(assigns, :events, assigns.data["events"] || [])

    ~H"""
    <svg class="dg" viewBox="0 0 470 150" role="img" aria-label={@label}>
      <line class="d-axis" x1="10" y1="76" x2="450" y2="76" />
      <%= for {ev, i} <- Enum.with_index(@events) do %>
        <% n = length(@events)
        x = if n > 1, do: 40 + i * div(390, n - 1), else: 235 %>
        <%!-- The end labels anchor outward: centring them clips the first note
              against the left edge of the viewBox. --%>
        <% anchor =
          cond do
            i == 0 -> "start"
            i == n - 1 -> "end"
            true -> "middle"
          end

        lx =
          cond do
            i == 0 -> 0
            i == n - 1 -> 470
            true -> x
          end %>
        <circle cx={x} cy="76" r="6" class={["d-node", ev["accent"] && "d-node--a"]} />
        <text class="d-num" x={lx} y="44" text-anchor={anchor}>{ev["time"]}</text>
        <text class="d-labm" x={lx} y="60" text-anchor={anchor}>{ev["label"]}</text>
        <text class="d-labm" x={lx} y="100" text-anchor={anchor} style={tone_style(ev["tone"])}>
          {ev["note"]}
        </text>
      <% end %>
    </svg>
    """
  end

  # 07 — what the sample allows you to conclude. The whiskers are the interval;
  # a bar that spans the axis is the whole point of the form.
  defp intervalo(assigns) do
    assigns = assign(assigns, :rows, assigns.data["rows"] || [])

    ~H"""
    <svg class="dg" viewBox="0 0 470 150" role="img" aria-label={@label}>
      <line class="d-axis" x1="40" y1="128" x2="430" y2="128" />
      <%= for {t, i} <- Enum.with_index(@data["ticks"] || []) do %>
        <text class="d-labm" x={40 + i * 195} y="145" text-anchor="middle">{t}</text>
      <% end %>

      <%= for {row, i} <- Enum.with_index(@rows) do %>
        <% y = i * 48 + 40
        cls = if row["accent"], do: "d-edge--a", else: "d-edge"
        lo = scale(row["lo"])
        hi = scale(row["hi"]) %>
        <text class="d-labm" x="0" y={y + 4}>{row["label"]}</text>
        <line class={cls} x1={lo} y1={y} x2={hi} y2={y} stroke-width="2" />
        <line class={cls} x1={lo} y1={y - 8} x2={lo} y2={y + 8} stroke-width="2" />
        <line class={cls} x1={hi} y1={y - 8} x2={hi} y2={y + 8} stroke-width="2" />
        <circle
          cx={scale(row["point"])}
          cy={y}
          r="5"
          class={["d-node", row["accent"] && "d-node--a"]}
        />
        <text class="d-labm" x={scale(row["point"])} y={y - 18} text-anchor="middle">
          {row["note"]}
        </text>
      <% end %>
    </svg>
    """
  end

  # The axis runs 0,4 to 1,0 across 390px, so callers give real values and the
  # drawing places them. Hand-computed pixels drift the moment a number changes.
  defp scale(v) when is_number(v), do: round(40 + (v - 0.4) / 0.6 * 390)
  defp scale(_), do: 40

  defp bar(v, max) when is_number(v) and is_number(max) and max > 0,
    do: max(round(v / max * 110), 9)

  defp bar(_, _), do: 9

  defp tone_style("bad"), do: "fill: var(--bad);"
  defp tone_style("good"), do: "fill: var(--good);"
  defp tone_style("warn"), do: "fill: var(--warn);"
  defp tone_style(_), do: nil

  # A curve with no centre or no spread has nothing to draw. It used to raise,
  # which took down the article's public page — and, once the social card
  # existed, the card too. Data typed into the editor reaches here directly, so
  # incomplete data has to degrade into an empty path rather than an exception.
  defp bell(center, spread, _base) when not is_number(center) or not is_number(spread), do: ""
  defp bell(_center, spread, _base) when spread <= 0, do: ""

  defp bell(center, spread, base) do
    left = round(center - spread * 3)
    right = round(center + spread * 3)

    pts =
      for x <- left..right//4 do
        y = base - 44 * :math.exp(-0.5 * :math.pow((x - center) / spread, 2))
        Integer.to_string(x) <> " " <> Float.to_string(Float.round(y * 1.0, 1))
      end

    "M #{left} #{base} L " <> Enum.join(pts, " L ") <> " L #{right} #{base} Z"
  end

  @doc "The arrowhead every form points with. Rendered once per page."
  def defs(assigns) do
    ~H"""
    <svg class="d-defs" aria-hidden="true">
      <defs>
        <marker
          id="d-arrow"
          viewBox="0 0 10 10"
          refX="9"
          refY="5"
          markerWidth="6"
          markerHeight="6"
          orient="auto-start-reverse"
        >
          <path class="d-arrow" d="M0 0 L10 5 L0 10 z" />
        </marker>
      </defs>
    </svg>
    """
  end
end
