defmodule BlogoWeb.AuthorHTML do
  use BlogoWeb, :html

  embed_templates "author_html/*"

  defdelegate format_date(dt), to: BlogoWeb.PostHTML

  def pretty_host(url) do
    case URI.parse(url) do
      %URI{host: h} when is_binary(h) -> String.replace_prefix(h, "www.", "")
      _ -> url
    end
  end
end
