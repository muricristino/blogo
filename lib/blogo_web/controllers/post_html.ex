defmodule BlogoWeb.PostHTML do
  use BlogoWeb, :html

  embed_templates "post_html/*"

  @meses ~w(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)
  @abrev ~w(jan fev mar abr mai jun jul ago set out nov dez)

  def format_date(nil), do: ""
  def format_date(%DateTime{} = d), do: "#{d.day} #{Enum.at(@abrev, d.month - 1)} #{d.year}"

  def format_date_long(nil), do: ""

  def format_date_long(%DateTime{} = d),
    do: "#{d.day} de #{Enum.at(@meses, d.month - 1)} de #{d.year}"

  def initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  @doc """
  The article's own diagram. Every published article has one, so the card and
  the list never fall back to a placeholder that says nothing.
  """
  attr :post, :map, required: true
  attr :caption, :boolean, default: false

  def hero(assigns) do
    ~H"""
    <div :if={@post.hero} class="hero">
      <.diagram
        form={@post.hero["form"]}
        data={@post.hero["data"] || %{}}
        label={@post.hero["alt"] || ""}
      />
      <p :if={@caption && @post.hero["caption"]} class="small">{@post.hero["caption"]}</p>
    </div>
    """
  end

  defdelegate parts_label(count), to: BlogoWeb.SeriesHTML

  @doc """
  Where an article sits among the *published* parts, which is not its
  `series_position`: an unpublished part 2 would make part 3 introduce itself
  as "parte 3 de 2".
  """
  def part_of(series, post) do
    case Enum.find_index(series.posts, &(&1.id == post.id)) do
      nil -> 1
      i -> i + 1
    end
  end
end
