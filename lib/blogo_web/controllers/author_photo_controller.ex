defmodule BlogoWeb.AuthorPhotoController do
  @moduledoc """
  Serves the author's photo out of the database.

  The blog is self-hosted, so the face on it comes from the same machine as the
  writing: no Gravatar, no third-party CDN, nothing the blog's owner cannot
  turn off. That leaves the question of where the bytes sit, and in this
  deployment there is only one durable answer — the application's container is
  replaced on every deploy and mounts no volume, while Postgres runs in its own
  container with its own data. So the photo is a column, and this is the
  request that reads it.

  `path/1` and `url/2` live here rather than in the templates so the address,
  the cache key and the route that answers them cannot drift apart.
  """
  use BlogoWeb, :controller

  alias Blogo.Content

  # Enough of the digest to be a cache key, short enough to read in a URL.
  @key_length 12

  @doc """
  Where the photo is served, with the digest as a cache key, or nil when the
  author has none. The key is what lets the response be cached for a year: a
  new photo is a different address, so nothing has to be invalidated.
  """
  def path(author) do
    if Content.Author.photo?(author) do
      ~p"/autor/#{author.slug}/foto?#{[v: key(author.photo_digest)]}"
    end
  end

  @doc """
  The photo's canonical address, without the cache key — what goes into
  structured data, where a URL is an identifier and not a request.
  """
  def url(author, base_url) do
    if Content.Author.photo?(author), do: "#{base_url}/autor/#{author.slug}/foto"
  end

  def show(conn, %{"slug" => slug} = params) do
    case Content.author_photo(slug) do
      nil ->
        conn |> put_status(:not_found) |> text("Não encontrado")

      photo ->
        conn
        # No charset: `put_resp_content_type/2` appends utf-8 by default, which
        # says nothing true about a PNG.
        |> put_resp_content_type(photo.type, nil)
        |> put_resp_header("etag", ~s("#{photo.digest}"))
        |> put_resp_header("cache-control", cache_control(params, photo.digest))
        |> respond(photo)
    end
  end

  # A request that carries the current digest is asking for bytes that cannot
  # change, so it is answered for a year. One without it — a link written by
  # hand, or an old page — gets a short life instead, or a photo replaced today
  # would stay wrong in a reader's browser until next year.
  defp cache_control(params, digest) do
    if params["v"] == key(digest) do
      "public, max-age=31536000, immutable"
    else
      "public, max-age=300"
    end
  end

  defp respond(conn, photo) do
    if fresh?(conn, photo.digest) do
      send_resp(conn, :not_modified, "")
    else
      send_resp(conn, :ok, photo.data)
    end
  end

  defp fresh?(conn, digest) do
    etag = ~s("#{digest}")
    Enum.any?(get_req_header(conn, "if-none-match"), &(&1 == etag or &1 == "*"))
  end

  defp key(digest), do: String.slice(digest, 0, @key_length)
end
