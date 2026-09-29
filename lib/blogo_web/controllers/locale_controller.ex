defmodule BlogoWeb.LocaleController do
  @moduledoc """
  The one endpoint the language selector posts to.

  It is a POST because it changes something that lasts, and it answers with a
  redirect back to where the reader was.

  Usually that is the same address. The exception is an article that exists in
  the language just picked: pressing EN on a Portuguese text means "give me
  this in English", and repainting the menu while leaving the Portuguese text
  in place is the one thing it does not mean. The redirect goes to the sibling.

  Resolving it here rather than in the selector keeps it in one place and makes
  it work from anywhere — the selector renders in the bar and in the footer, on
  every page, and none of them has to know about translations.

  `return_to` comes from the form, which means it comes from whoever is asking,
  so it is only honoured when it is a path on this site. An open redirect is
  what a "harmless" hidden field turns into.
  """
  use BlogoWeb, :controller

  def update(conn, params) do
    locale = params["locale"]
    path = safe_path(params["return_to"])

    conn
    |> BlogoWeb.Locale.choose(locale)
    |> redirect(to: sibling_path(path, locale))
  end

  # A path is an article's only when it is a single segment: `/tag/x` and
  # `/busca` are not articles, and neither is `/`.
  defp sibling_path("/" <> slug = path, locale) do
    language = BlogoWeb.Locale.tag(locale)

    with false <- String.contains?(slug, "/"),
         %{} = post <- Blogo.Content.get_published_by_slug(slug),
         %{^language => sibling} <- Blogo.Content.translations_of(post) do
      "/" <> sibling
    else
      _ -> path
    end
  end

  defp sibling_path(path, _locale), do: path

  defp safe_path("/" <> rest = path) do
    # "//host" is a protocol-relative URL: a path by the look of it and another
    # origin in practice.
    if String.starts_with?(rest, "/") or String.contains?(path, "\\"), do: "/", else: path
  end

  defp safe_path(_path), do: "/"
end
