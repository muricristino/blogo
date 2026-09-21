defmodule BlogoWeb.PostHTML do
  use BlogoWeb, :html

  embed_templates "post_html/*"

  def format_date(nil), do: ""

  def format_date(%DateTime{} = dt) do
    meses = ~w(jan fev mar abr mai jun jul ago set out nov dez)
    "#{dt.day} #{Enum.at(meses, dt.month - 1)} #{dt.year}"
  end
end
