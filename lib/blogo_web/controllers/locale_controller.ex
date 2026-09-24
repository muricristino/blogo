defmodule BlogoWeb.LocaleController do
  @moduledoc """
  The one endpoint the language selector posts to.

  It is a POST because it changes something that lasts, and it answers with a
  redirect back to the page the reader was on — the same address, in the other
  language. Nothing about the article's URL encodes a language, so there is
  nothing to rewrite here.

  `return_to` comes from the form, which means it comes from whoever is asking,
  so it is only honoured when it is a path on this site. An open redirect is
  what a "harmless" hidden field turns into.
  """
  use BlogoWeb, :controller

  def update(conn, params) do
    conn
    |> BlogoWeb.Locale.choose(params["locale"])
    |> redirect(to: safe_path(params["return_to"]))
  end

  defp safe_path("/" <> rest = path) do
    # "//host" is a protocol-relative URL: a path by the look of it and another
    # origin in practice.
    if String.starts_with?(rest, "/") or String.contains?(path, "\\"), do: "/", else: path
  end

  defp safe_path(_path), do: "/"
end
