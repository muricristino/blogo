defmodule BlogoWeb.FeedController do
  @moduledoc """
  An Atom feed at `/feed.xml`.

  Atom rather than RSS 2.0 for three reasons that are all about ambiguity:
  `id` is required and permanent, where RSS's `guid` is optional and its
  permalink semantics are a convention; dates are RFC 3339, where RSS 2.0 uses
  RFC 822 and broken dates are the classic reason a feed silently stops
  updating; and content carries an explicit type, where RSS leaves escaping to
  be guessed. Every reader worth having supports both.

  The feed carries the summary and a link, not the rendered article. A diagram
  here is an SVG whose fills come from stylesheet classes, and no feed reader
  loads the stylesheet — the article would arrive with blank boxes where its
  figures are. A summary that sends the reader to the real page is the honest
  version.
  """
  use BlogoWeb, :controller

  alias Blogo.Content

  def index(conn, _params) do
    base = BlogoWeb.Endpoint.url()
    site = Content.the_site()
    posts = Content.list_published()
    author = Content.the_author()

    updated =
      posts
      |> Enum.map(& &1.updated_at)
      |> Enum.reject(&is_nil/1)
      |> Enum.max(DateTime, fn -> DateTime.utc_now() end)

    body = """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom" xml:lang="pt-BR">
      <title>#{esc(Content.site_name(site))}</title>
      #{if site.description, do: "<subtitle>#{esc(site.description)}</subtitle>", else: ""}
      <link href="#{base}/feed.xml" rel="self" type="application/atom+xml"/>
      <link href="#{base}/" rel="alternate" type="text/html"/>
      <id>#{base}/</id>
      <updated>#{DateTime.to_iso8601(updated)}</updated>
      #{if author, do: autor(author), else: ""}
    #{Enum.map_join(posts, "\n", &entrada(&1, base))}
    </feed>
    """

    conn
    |> put_resp_content_type("application/atom+xml", "utf-8")
    |> send_resp(200, body)
  end

  defp autor(author) do
    """
    <author>
        <name>#{esc(author.name)}</name>
      </author>
    """
    |> String.trim()
  end

  defp entrada(post, base) do
    """
      <entry>
        <title>#{esc(post.title)}</title>
        <link href="#{base}/#{post.slug}" rel="alternate" type="text/html"/>
        <id>#{base}/#{post.slug}</id>
        <published>#{DateTime.to_iso8601(post.published_at)}</published>
        <updated>#{DateTime.to_iso8601(post.updated_at)}</updated>
        <summary type="text">#{esc(post.meta_description || post.subtitle || "")}</summary>
    #{Enum.map_join(post.topics, "\n", &"    <category term=\"#{esc(&1)}\"/>")}
      </entry>
    """
    |> String.trim_trailing()
  end

  # XML has five reserved characters and an article title is free text.
  defp esc(nil), do: ""

  defp esc(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
