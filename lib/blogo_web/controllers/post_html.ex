defmodule BlogoWeb.PostHTML do
  use BlogoWeb, :html

  embed_templates "post_html/*"

  @meses ~w(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)
  @abrev ~w(jan fev mar abr mai jun jul ago set out nov dez)

  def format_date(nil), do: ""
  def format_date(%DateTime{} = d), do: "#{d.day} #{Enum.at(@abrev, d.month - 1)} #{d.year}"

  def format_date_long(nil), do: ""
  def format_date_long(%DateTime{} = d), do: "#{d.day} de #{Enum.at(@meses, d.month - 1)} de #{d.year}"

  def initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  def status_serie(%{done: 0}), do: "não iniciada"
  def status_serie(%{done: d, parts: p}) when d >= p, do: "completa"
  def status_serie(%{done: d, parts: p}), do: "#{d} de #{p} lidos"

  @doc "The two densities from the featured post, as the card's only ornament."
  def featured_curves(assigns) do
    ~H"""
    <svg viewBox="0 0 320 140" class="dg" role="img"
         aria-label="Duas distribuições separadas e duas sobrepostas, com AUC 0,890 e 0,508">
      <line class="d-axis" x1="6" y1="56" x2="250" y2="56" />
      <path class="d-fill-m" d="M30 56 Q70 4 110 56 Z" />
      <path class="d-fill-a" d="M150 56 Q190 4 230 56 Z" />
      <text class="d-num" x="262" y="50">0,890</text>

      <line class="d-axis" x1="6" y1="126" x2="250" y2="126" />
      <path class="d-fill-m" d="M70 126 Q110 74 150 126 Z" />
      <path class="d-fill-a" d="M110 126 Q150 74 190 126 Z" />
      <text class="d-num" x="262" y="120">0,508</text>
    </svg>
    """
  end

  @doc "The placeholder mark each list item carries where its diagram will go."
  def thumb_mark(assigns) do
    ~H"""
    <svg viewBox="0 0 90 60" width="90" height="60" aria-hidden="true">
      <rect class="d-node" x="4" y="18" width="30" height="20" rx="6" />
      <line class="d-edge" x1="36" y1="28" x2="50" y2="28" marker-end="url(#d-arrow)" />
      <rect class="d-fill-a" x="54" y="18" width="30" height="20" rx="6" />
    </svg>
    """
  end
end
