defmodule BlogoWeb.MarkdownAlternate do
  @moduledoc """
  Serves `/endereco.md`: the article as the markdown it was written in.

  It costs almost nothing here — the conversion already exists in both
  directions and is covered by round-trip properties — and it is the format a
  model reads with the least loss. The HTML page points at it with
  `rel="alternate"`, and `llms.txt` links every article by this address.

  ## Why a plug and not a route

  A route matches whole segments, so it cannot carry an extension; `/imagem/:slug`
  strips `.png` in its controller for the same reason. This one runs *before*
  `:accepts` in the pipeline, which is the part that matters: that plug speaks
  HTML, so a client asking for `text/markdown` and nothing else would get 406
  from the very address built to answer it.

  ## The canonical stays on the HTML

  The markdown is a second representation of one article, not a second article.
  It says so in a `Link` header rather than in the body, because a text document
  has no `<head>` to put a `<link rel="canonical">` in, and that header is what
  a crawler reads for a non-HTML resource.
  """
  import Plug.Conn

  alias Blogo.Content
  alias Blogo.Content.Llms

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: method, path_info: [segment]} = conn, _opts)
      when method in ["GET", "HEAD"] do
    if String.ends_with?(segment, ".md") do
      serve(conn, String.replace_suffix(segment, ".md", ""))
    else
      conn
    end
  end

  def call(conn, _opts), do: conn

  # An address that is not a published article falls through to the router,
  # which answers 404 — or 301, if the article moved.
  defp serve(conn, slug) do
    case Content.get_published_by_slug(slug) do
      nil ->
        conn

      post ->
        base_url = BlogoWeb.Endpoint.url()

        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header("link", ~s(<#{base_url}/#{post.slug}>; rel="canonical"))
        |> send_resp(200, Llms.document(post, base_url))
        |> halt()
    end
  end
end
