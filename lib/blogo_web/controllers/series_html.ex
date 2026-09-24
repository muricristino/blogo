defmodule BlogoWeb.SeriesHTML do
  use BlogoWeb, :html

  embed_templates "series_html/*"

  defdelegate format_date(dt), to: BlogoWeb.PostHTML
  defdelegate hero(assigns), to: BlogoWeb.PostHTML

  @doc "How many parts are published — a fact, where the old bar showed progress."
  def parts_label(1), do: "1 parte"
  def parts_label(n), do: "#{n} partes"
end
