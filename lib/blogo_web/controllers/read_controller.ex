defmodule BlogoWeb.ReadController do
  @moduledoc """
  Receives the one beacon an article sends when the reader leaves it.

  This is the only route on the site that lets an anonymous request write a
  row, so it is signed: the article page embeds a token bound to its own slug,
  and a beacon without a valid one is dropped. That costs nothing to serve and
  means the reading figures cannot be invented with a shell loop — which
  matters more here than it looks, because a number in the panel is used to
  decide what to write next.

  It always answers 204, whatever happened. The browser has already navigated
  away and cannot act on a status code, and telling a caller *why* their
  forged token failed is free help for the next attempt.
  """
  use BlogoWeb, :controller

  alias Blogo.Analytics
  alias Blogo.Content

  @salt "read beacon"
  @max_age 6 * 60 * 60

  def create(conn, params) do
    with {:ok, slug} <- verify(params["token"]),
         %{id: id} <- Content.get_published_by_slug(slug) do
      Analytics.record_read(id, %{
        depth: to_int(params["depth"]),
        seconds: to_int(params["seconds"]),
        source:
          Analytics.classify(params["referrer"], params["utm_source"], BlogoWeb.Endpoint.host())
      })
    end

    send_resp(conn, :no_content, "")
  end

  @doc """
  The token an article page carries, bound to its slug.

  Signed against the endpoint rather than the conn: the secret is the
  endpoint's either way, and a conn that has not been through the endpoint yet
  — which is every conn in a controller test — has no key base to offer.
  """
  def token(slug), do: Phoenix.Token.sign(BlogoWeb.Endpoint, @salt, slug)

  defp verify(token) when is_binary(token) do
    Phoenix.Token.verify(BlogoWeb.Endpoint, @salt, token, max_age: @max_age)
  end

  defp verify(_token), do: :error

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _rest} -> n
      :error -> 0
    end
  end

  defp to_int(_value), do: 0
end
