defmodule BlogoWeb.CardControllerTest do
  use BlogoWeb.ConnCase

  alias Blogo.Fixtures

  test "serves the card as a PNG", %{conn: conn} do
    post = Fixtures.post()
    conn = get(conn, "/imagem/#{post.slug}.png")

    assert ["image/png"] = get_resp_header(conn, "content-type")
    assert <<0x89, "PNG", _::binary>> = response(conn, 200)
  end

  test "works without the extension too", %{conn: conn} do
    post = Fixtures.post()
    assert conn |> get(~p"/imagem/#{post.slug}") |> response(200)
  end

  # A crawler that already has the card should not make the server draw it
  # again — that is what keeps generating on demand affordable.
  test "a crawler that already has it gets 304", %{conn: conn} do
    post = Fixtures.post()
    first = get(conn, "/imagem/#{post.slug}.png")
    [etag] = get_resp_header(first, "etag")

    second =
      build_conn()
      |> put_req_header("if-none-match", etag)
      |> get("/imagem/#{post.slug}.png")

    assert response(second, 304)
  end

  test "a draft has no card", %{conn: conn} do
    post = Fixtures.post(%{status: "draft"})
    assert conn |> get("/imagem/#{post.slug}.png") |> response(404)
  end

  test "the article page points at its card", %{conn: conn} do
    post = Fixtures.post()
    html = conn |> get(~p"/#{post.slug}") |> html_response(200)

    assert html =~ ~s(property="og:image")
    assert html =~ "/imagem/#{post.slug}.png"
    assert html =~ ~s(name="twitter:card" content="summary_large_image")
  end
end
