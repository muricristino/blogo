defmodule BlogoWeb.CanonicalHost do
  @moduledoc """
  Sends every request for another hostname to the canonical one, with a 301.

  A blog reachable at two addresses is two addresses serving the same text, and
  a search engine picks one of them without consulting anybody. `canonical`
  states a preference; a 301 settles it, and it also carries whatever link
  equity the old address had.

  The canonical host is `PHX_HOST`, through the endpoint's configured url — the
  same source the canonical tag, `og:url` and the schema.org `@id` read, so the
  four cannot disagree.

  Nothing is redirected while the canonical host is itself local, which is what
  development and the test suite look like: with no real domain configured
  there is no canonical address to send anyone to, and a rule that fires there
  would only break the request that was already going to the right place.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{host: host} = conn, _opts) do
    canonical = canonical_host()

    if redirect?(host, canonical) do
      # 301 and not the default 302: a temporary redirect tells a search engine
      # the old address is still the real one, and carries no link equity over.
      conn
      |> Plug.Conn.put_status(:moved_permanently)
      |> Phoenix.Controller.redirect(external: canonical_url(conn, canonical))
      |> Plug.Conn.halt()
    else
      conn
    end
  end

  # Read at request time rather than through `Endpoint.host/0`, which resolves
  # once at boot: the value is the same in production and this way a test can
  # set a domain and see the rule behave.
  defp canonical_host do
    :blogo
    |> Application.get_env(BlogoWeb.Endpoint, [])
    |> Keyword.get(:url, [])
    |> Keyword.get(:host, "localhost")
  end

  defp redirect?(host, canonical) do
    host != canonical and not local?(canonical) and not local?(host)
  end

  defp local?(host), do: is_nil(host) or host in ["localhost", "127.0.0.1", "0.0.0.0", ""]

  # The path and the query survive the move: a link to an article on the old
  # address lands on that article, not on the front page.
  defp canonical_url(conn, canonical) do
    query = if conn.query_string in [nil, ""], do: "", else: "?" <> conn.query_string

    "https://#{canonical}#{conn.request_path}#{query}"
  end
end
