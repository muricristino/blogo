defmodule BlogoWeb.AuthorPhotoControllerTest do
  @moduledoc """
  The photo is served by this application, out of its own database. That is the
  point of it: a self-hosted blog whose face comes from Gravatar or a CDN has a
  piece of itself that its owner cannot turn off.
  """
  use BlogoWeb.ConnCase

  alias Blogo.Content
  alias Blogo.Fixtures

  defp with_photo(bytes \\ nil) do
    author = Fixtures.author()
    bytes = bytes || Fixtures.png()
    {:ok, _} = Content.put_author_photo(author, bytes)
    %{author: Content.get_author!(author.id), bytes: bytes}
  end

  test "the bytes come back, as the type they actually are", %{conn: conn} do
    %{author: author, bytes: bytes} = with_photo(Fixtures.jpeg())

    conn = get(conn, ~p"/autor/#{author.slug}/foto")

    assert conn.status == 200
    assert conn.resp_body == bytes
    assert get_resp_header(conn, "content-type") == ["image/jpeg"]
  end

  test "an author without a photo answers 404 rather than an empty image", %{conn: conn} do
    author = Fixtures.author()

    conn = get(conn, ~p"/autor/#{author.slug}/foto")

    assert conn.status == 404
  end

  test "a slug nobody has answers 404", %{conn: conn} do
    assert get(conn, ~p"/autor/ninguem/foto").status == 404
  end

  describe "caching" do
    # The photo sits at the end of every article, so it is requested on every
    # page. The digest in the address is what makes a year-long cache safe: a
    # new photo is a new address, and nothing has to be invalidated.
    test "a request carrying the current digest is cached for a year", %{conn: conn} do
      %{author: author} = with_photo()
      key = String.slice(author.photo_digest, 0, 12)

      conn = get(conn, ~p"/autor/#{author.slug}/foto?#{[v: key]}")

      assert ["public, max-age=31536000, immutable"] = get_resp_header(conn, "cache-control")
    end

    # A link written by hand has no digest in it, so it cannot promise the
    # bytes will not change. Caching it for a year would leave a photo replaced
    # today wrong in someone's browser until next year.
    test "a request without the digest is cached briefly", %{conn: conn} do
      %{author: author} = with_photo()

      conn = get(conn, ~p"/autor/#{author.slug}/foto")

      assert ["public, max-age=300"] = get_resp_header(conn, "cache-control")
    end

    test "a stale digest in the address does not buy the long cache", %{conn: conn} do
      %{author: author} = with_photo()

      conn = get(conn, ~p"/autor/#{author.slug}/foto?#{[v: "0123456789ab"]}")

      assert ["public, max-age=300"] = get_resp_header(conn, "cache-control")
    end

    test "a browser that already has these bytes is told so", %{conn: conn} do
      %{author: author} = with_photo()
      etag = ~s("#{author.photo_digest}")

      conn = conn |> put_req_header("if-none-match", etag) |> get(~p"/autor/#{author.slug}/foto")

      assert conn.status == 304
      assert conn.resp_body == ""
      assert get_resp_header(conn, "etag") == [etag]
    end

    test "a browser holding a different version gets the new bytes", %{conn: conn} do
      %{author: author, bytes: bytes} = with_photo()

      conn =
        conn
        |> put_req_header("if-none-match", ~s("outra-coisa"))
        |> get(~p"/autor/#{author.slug}/foto")

      assert conn.status == 200
      assert conn.resp_body == bytes
    end
  end
end
