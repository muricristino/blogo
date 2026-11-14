defmodule BlogoWeb.Api.PostImageControllerTest do
  use BlogoWeb.ConnCase

  alias Blogo.Content
  alias Blogo.Content.PostImage
  alias Blogo.Fixtures

  @token "token-de-teste"

  setup do
    previous = System.get_env("BLOGO_API_TOKEN")
    System.delete_env("BLOGO_API_TOKEN")
    Application.put_env(:blogo, :api_token, @token)
    Application.put_env(:blogo, :admin_password, "senha-de-teste")

    on_exit(fn ->
      Application.delete_env(:blogo, :api_token)
      Application.delete_env(:blogo, :admin_password)
      if previous, do: System.put_env("BLOGO_API_TOKEN", previous)
    end)

    post =
      Fixtures.post(%{
        status: "draft",
        published_at: nil,
        body: %{
          "blocks" => [
            %{"type" => "text", "paragraphs" => ["Antes."]},
            %{
              "type" => "image",
              "src" => "prints/rua.png",
              "alt" => "A rua à noite",
              "caption" => "A neblina esconde o fim."
            }
          ]
        }
      })

    %{post: post}
  end

  defp authed(conn) do
    conn
    |> put_req_header("authorization", "Bearer " <> @token)
    |> put_req_header("accept", "application/json")
  end

  defp upload(conn, slug, name, bytes) do
    conn |> authed() |> put("/api/posts/#{slug}/images/#{name}", %{data: Base.encode64(bytes)})
  end

  test "an upload is stored cleaned, read back from the database", %{conn: conn, post: post} do
    bytes = Fixtures.png(metadata: [{"tEXt", "GPS\0-23.56,-46.65"}])
    conn = upload(conn, post.slug, "prints/rua.png", bytes)

    assert %{"ok" => true, "outcome" => "created", "image" => image} = json_response(conn, 201)
    assert image["source_digest"] == PostImage.sha256(bytes)

    stored = Content.get_post_image(post, "prints/rua.png")
    assert stored.content_type == "image/png"
    refute stored.data =~ "GPS"
    assert stored.digest == image["digest"]
  end

  test "sending the same file twice changes nothing", %{conn: conn, post: post} do
    bytes = Fixtures.png(metadata: [{"tEXt", "comentário"}])
    upload(conn, post.slug, "a.png", bytes)
    before = Content.get_post_image(post, "a.png")

    conn = upload(build_conn(), post.slug, "a.png", bytes)
    assert json_response(conn, 200)["outcome"] == "unchanged"

    cleaned = Content.get_post_image(post, "a.png").data
    conn = upload(build_conn(), post.slug, "a.png", cleaned)
    assert json_response(conn, 200)["outcome"] == "unchanged"

    assert Content.get_post_image(post, "a.png").updated_at == before.updated_at
  end

  test "a different file under the same name replaces it", %{conn: conn, post: post} do
    upload(conn, post.slug, "a.png", Fixtures.png())
    conn = upload(build_conn(), post.slug, "a.png", Fixtures.png(width: 16))
    assert json_response(conn, 200)["outcome"] == "replaced"
    assert [%{name: "a.png"}] = Content.list_post_images(post)
  end

  test "refuses what is not an image, and names that climb out", %{conn: conn, post: post} do
    conn = upload(conn, post.slug, "a.png", "não é imagem")
    assert json_response(conn, 422)["error"]["message"] =~ "PNG, JPEG ou WebP"

    conn = upload(build_conn(), post.slug, ".escondido.png", Fixtures.png())
    assert json_response(conn, 422)["error"]["code"] == "invalid"
    assert Content.list_post_images(post) == []
  end

  test "lists, downloads and deletes", %{conn: conn, post: post} do
    bytes = Fixtures.png()
    upload(conn, post.slug, "prints/rua.png", bytes)

    conn = build_conn() |> authed() |> get("/api/posts/#{post.slug}/images")
    assert [%{"name" => "prints/rua.png", "url" => url}] = json_response(conn, 200)["images"]
    assert url =~ "/midia/"

    conn = build_conn() |> authed() |> get("/api/posts/#{post.slug}/images/prints/rua.png")
    assert Base.decode64!(json_response(conn, 200)["image"]["data"]) == bytes

    conn = build_conn() |> authed() |> delete("/api/posts/#{post.slug}/images/prints/rua.png")
    assert json_response(conn, 200)["ok"]
    assert Content.list_post_images(post) == []
  end

  test "needs the token", %{conn: conn, post: post} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put("/api/posts/#{post.slug}/images/a.png", %{data: Base.encode64(Fixtures.png())})

    assert json_response(conn, 401)["ok"] == false
  end

  test "the image is served by its digest, cached for good", %{conn: conn, post: post} do
    {:ok, image, :created} = Content.put_post_image(post, "a.png", Fixtures.png())

    conn = get(conn, PostImage.path(image))
    assert response(conn, 200) == Content.get_post_image(post, "a.png").data
    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]

    conn =
      build_conn()
      |> put_req_header("if-none-match", ~s("#{image.digest}"))
      |> get(PostImage.path(image))

    assert response(conn, 304)

    assert build_conn() |> get("/midia/#{String.duplicate("0", 64)}.png") |> response(404)
  end

  test "the preview draws the image, and a missing one says so", %{post: post} do
    html = build_conn() |> admin() |> get("/editor/#{post.id}/previa") |> html_response(200)
    assert html =~ "imagem ausente · prints/rua.png"

    {:ok, image, _} = Content.put_post_image(post, "prints/rua.png", Fixtures.png())
    html = build_conn() |> admin() |> get("/editor/#{post.id}/previa") |> html_response(200)
    assert html =~ ~s(src="#{PostImage.path(image)}")
    assert html =~ ~s(alt="A rua à noite")
    assert html =~ "A neblina esconde o fim."
  end

  test "the published article draws it too", %{post: post} do
    {:ok, image, _} = Content.put_post_image(post, "prints/rua.png", Fixtures.png())
    {:ok, post} = Content.publish_post(post)

    html = build_conn() |> get("/#{post.slug}") |> html_response(200)
    assert html =~ ~s(src="#{PostImage.path(image)}")
  end

  test "the article reserves the image's place before it loads", %{post: post} do
    {:ok, _image, _} =
      Content.put_post_image(post, "prints/rua.png", Fixtures.png(width: 32, height: 24))

    {:ok, post} = Content.publish_post(post)

    assert %{width: 32, height: 24} = Content.list_post_images(post) |> hd()

    html = build_conn() |> get("/#{post.slug}") |> html_response(200)
    assert html =~ ~r/<img[^>]*width="32"[^>]*height="24"/s
  end

  test "get then push with no edits changes nothing in the row", %{conn: conn, post: post} do
    {:ok, _} = Content.save_post(post, %{})

    conn = conn |> authed() |> get("/api/posts/#{post.slug}")
    %{"markdown" => markdown, "hero" => hero} = json_response(conn, 200)["post"]
    before = Content.get_post_by_slug(post.slug)

    conn =
      build_conn()
      |> authed()
      |> put("/api/posts/#{post.slug}", %{markdown: markdown, hero: hero})

    assert %{"created" => false, "changed" => false} = json_response(conn, 200)

    after_push = Content.get_post_by_slug(post.slug)
    assert after_push.body == before.body
    assert after_push.lock_version == before.lock_version
    assert after_push.updated_at == before.updated_at
  end

  defp admin(conn) do
    conn
    |> post(~p"/auth/login", %{"password" => "senha-de-teste"})
    |> recycle()
  end
end
