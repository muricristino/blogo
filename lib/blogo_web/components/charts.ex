defmodule BlogoWeb.Charts do
  @moduledoc """
  The four figures the panel draws, in the same idiom as `BlogoWeb.Diagrams`:
  inline SVG, no literal colour, every fill and stroke from a class so dark
  mode is a token swap.

  Each one takes measured values and nothing else. None of them invents a
  baseline, smooths a curve or extends a series to make it look fuller — a
  chart that flatters the data is the most expensive kind of lie in a panel,
  because it is the one nobody checks.
  """
  use Phoenix.Component

  @doc """
  A sparkline for a KPI card. Flat when every value is equal, which is the
  honest shape for a flat series.
  """
  attr :values, :list, required: true
  attr :label, :string, default: ""

  def sparkline(assigns) do
    assigns = assign(assigns, :points, points(assigns.values, 200, 40))

    ~H"""
    <svg :if={@points != []} class="ch" viewBox="0 0 200 40" role="img" aria-label={@label}>
      <path class="ch-area" d={area_path(@points, 40)} />
      <path class="ch-line" d={line_path(@points)} />
      <circle class="ch-dot" cx={last_x(@points)} cy={last_y(@points)} r="3.5" />
    </svg>
    """
  end

  @doc """
  Reads per day. The tallest bar takes the accent, because the question asked
  of this chart is almost always "what happened on the best day".
  """
  attr :series, :list, required: true
  attr :label, :string, default: ""

  def bars(assigns) do
    assigns = assign(assigns, :geometry, bar_geometry(assigns.series))

    ~H"""
    <svg class="ch ch--wide" viewBox="0 0 700 178" role="img" aria-label={@label}>
      <line :for={y <- [30, 85, 140]} class="ch-grid" x1="0" y1={y} x2="640" y2={y} />
      <text :for={{y, text} <- @geometry.axis} class="ch-axis" x="648" y={y}>{text}</text>

      <rect
        :for={bar <- @geometry.bars}
        class={["ch-bar", bar.peak? && "ch-bar--on"]}
        x={bar.x}
        y={bar.y}
        width={bar.width}
        height={bar.height}
        rx="3"
      >
        <title>{bar.title}</title>
      </rect>

      <text
        :for={{x, text, anchor} <- @geometry.days}
        class="ch-axis"
        x={x}
        y="162"
        text-anchor={anchor}
      >
        {text}
      </text>
    </svg>
    """
  end

  @doc """
  Where the reads came from. One row per source, widest first.
  """
  attr :rows, :list, required: true
  attr :label, :string, default: ""

  def hbars(assigns) do
    assigns = assign(assigns, :height, max(length(assigns.rows) * 28, 28))

    ~H"""
    <svg class="ch" viewBox={"0 0 320 #{@height}"} role="img" aria-label={@label}>
      <g :for={{row, i} <- Enum.with_index(@rows)}>
        <text class="ch-axis ch-axis--name" x="0" y={i * 28 + 14}>{row.source}</text>
        <rect
          class={["ch-bar", i == 0 && "ch-bar--on"]}
          x="92"
          y={i * 28 + 4}
          width={max(row.pct * 1.55, 3)}
          height="12"
          rx="3"
        />
        <text class="ch-lab" x={92 + max(row.pct * 1.55, 3) + 8} y={i * 28 + 14}>{row.pct}%</text>
      </g>
    </svg>
    """
  end

  @doc """
  How far readers got. The first point is 100 by definition rather than by
  measurement, so it is drawn without a marker — a dot there would invite a
  reading it cannot support.
  """
  attr :curve, :list, required: true
  attr :label, :string, default: ""

  def depth(assigns) do
    assigns = assign(assigns, :points, depth_points(assigns.curve))

    ~H"""
    <svg :if={@points != []} class="ch" viewBox="0 0 320 120" role="img" aria-label={@label}>
      <line class="ch-grid" x1="0" y1="96" x2="300" y2="96" />
      <path class="ch-area" d={area_path(@points, 96)} />
      <path class="ch-line" d={line_path(@points)} />
      <circle class="ch-dot" cx={last_x(@points)} cy={last_y(@points)} r="3.5" />
      <text class="ch-lab" x="6" y="9">100%</text>
      <text class="ch-lab" x="292" y={label_y(last_y(@points))} text-anchor="end">
        {List.last(@curve).pct}%
      </text>
      <text class="ch-axis" x="0" y="112">abertura</text>
      <text class="ch-axis" x="300" y="112" text-anchor="end">fim</text>
    </svg>
    """
  end

  # ── geometry ──────────────────────────────────────────────────────────────

  defp points([], _width, _height), do: []
  defp points(values, _width, _height) when length(values) < 2, do: []

  defp points(values, width, height) do
    {low, high} = Enum.min_max(values)
    span = if high == low, do: 1, else: high - low
    step = width / (length(values) - 1)
    # Two pixels of padding top and bottom: a series that touches the extremes
    # of its own box loses its first and last point to the clip.
    usable = height - 6

    values
    |> Enum.with_index()
    |> Enum.map(fn {value, i} ->
      y = if high == low, do: height / 2, else: 3 + usable - (value - low) / span * usable
      {round1(i * step), round1(y)}
    end)
  end

  defp depth_points([]), do: []

  defp depth_points(curve) do
    step = 300 / max(length(curve) - 1, 1)

    curve
    |> Enum.with_index()
    |> Enum.map(fn {%{pct: pct}, i} ->
      {round1(i * step), round1(12 + (100 - pct) * 0.72)}
    end)
  end

  defp clamp(value, low, high), do: value |> max(low) |> min(high)

  # Rounds whatever arithmetic produced, integer or float. `Float.round/2`
  # refuses an integer, and which one comes out depends on the data.
  defp round1(value), do: value |> :erlang.float() |> Float.round(1)

  defp line_path(points) do
    points
    |> Enum.map_join(" ", fn {x, y} -> "L#{x} #{y}" end)
    |> String.replace_prefix("L", "M")
  end

  defp area_path(points, floor) do
    {first_x, _} = List.first(points)
    {last_x, _} = List.last(points)
    line_path(points) <> " L#{last_x} #{floor} L#{first_x} #{floor} Z"
  end

  # Above the point normally, below it when the point is near the top, so the
  # label never lands on its own marker.
  defp label_y(y) when y < 22, do: y + 16
  defp label_y(y), do: y - 8

  defp last_x(points), do: points |> List.last() |> elem(0)
  defp last_y(points), do: points |> List.last() |> elem(1)

  defp bar_geometry([]), do: %{bars: [], axis: [], days: []}

  defp bar_geometry(series) do
    counts = Enum.map(series, & &1.count)
    peak = Enum.max(counts)
    top = ceiling_for(peak)
    n = length(series)

    slot = 640 / n
    width = clamp(slot - 9.0, 3.0, 18.0)

    bars =
      series
      |> Enum.with_index()
      |> Enum.map(fn {%{day: day, count: count}, i} ->
        # A day with one read still gets two pixels: a bar too short to see is
        # indistinguishable from a day nobody came, and those are different
        # facts.
        height =
          if top == 0, do: 0.0, else: count / top * 110.0

        height = if count > 0, do: max(height, 2.0), else: 0.0

        %{
          x: round1(i * slot + (slot - width) / 2),
          y: round1(140.0 - height),
          width: round1(width),
          height: round1(height),
          peak?: count == peak and count > 0,
          title: "#{format_day(day)} · #{count} #{if count == 1, do: "leitura", else: "leituras"}"
        }
      end)

    %{
      bars: bars,
      axis: [{34, format_int(top)}, {89, format_int(div(top, 2))}, {144, "0"}],
      days: day_labels(series, slot)
    }
  end

  # Only the ends and the middle are labelled: thirty dates along an axis this
  # wide overlap into a grey smear.
  defp day_labels(series, slot) do
    n = length(series)
    middle = div(n, 2)

    [
      {0, series |> List.first() |> Map.fetch!(:day) |> format_day(), "start"},
      {middle * slot + slot / 2, series |> Enum.at(middle) |> Map.fetch!(:day) |> format_day(),
       "middle"},
      {640, series |> List.last() |> Map.fetch!(:day) |> format_day(), "end"}
    ]
    |> Enum.uniq_by(fn {_x, text, _anchor} -> text end)
  end

  # A round ceiling so the two gridlines land on numbers a person would say.
  defp ceiling_for(0), do: 10

  defp ceiling_for(peak) do
    magnitude = :math.pow(10, floor(:math.log10(peak))) |> round()
    step = max(div(magnitude, 2), 1)
    ceil_div(peak, step * 2) * step * 2
  end

  defp ceil_div(a, b), do: div(a + b - 1, b)

  @months ~w(jan fev mar abr mai jun jul ago set out nov dez)

  defp format_day(%Date{} = day), do: "#{day.day} #{Enum.at(@months, day.month - 1)}"

  defp format_int(n) do
    n
    |> to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1.")
    |> String.reverse()
  end
end
