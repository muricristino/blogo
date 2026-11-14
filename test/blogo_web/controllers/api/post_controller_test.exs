defmodule BlogoWeb.Api.PostControllerTest do
  use BlogoWeb.ConnCase

  alias Blogo.Content
  alias Blogo.Fixtures

  @token "token-de-teste"

  @markdown """
  ---
  titulo: Um texto pela API
  resumo: Escrito num arquivo.
  endereco: outro-endereco
  marcadores: [api, cli]
  ---

  Primeiro parágrafo.

  ## 01 Uma seção

  Segundo parágrafo.
  """

  @hero %{
    "type" => "diagram",
    "form" => "linha_tempo",
    "alt" => "Do protótipo ao jogo em uma noite",
    "data" => %{"events" => [%{"time" => "21h", "label" => "início"}]}
  }

  setup do
    previous = System.get_env("BLOGO_API_TOKEN")
    System.delete_env("BLOGO_API_TOKEN")
    Application.put_env(:blogo, :api_token, @token)

    on_exit(fn ->
      Application.delete_env(:blogo, :api_token)
      if previous, do: System.put_env("BLOGO_API_TOKEN", previous)
    end)

    author = Fixtures.author()
    %{author: author}
  end

  defp authed(conn, token \\ @token) do
    conn
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_req_header("accept", "application/json")
  end

  describe "who gets in" do
    test "no token configured refuses every request, even one carrying a token", %{conn: conn} do
      Application.delete_env(:blogo, :api_token)

      conn = conn |> authed("") |> get(~p"/api/posts")
      assert %{"ok" => false, "error" => %{"code" => "api_disabled"}} = json_response(conn, 403)

      conn = build_conn() |> authed("qualquer-coisa") |> get(~p"/api/posts")
      assert json_response(conn, 403)["error"]["code"] == "api_disabled"
    end

    test "an empty token configured counts as none", %{conn: conn} do
      Application.put_env(:blogo, :api_token, "")
      conn = conn |> authed("") |> get(~p"/api/posts")
      assert json_response(conn, 403)["error"]["code"] == "api_disabled"
    end

    test "a missing token is refused", %{conn: conn} do
      conn = conn |> put_req_header("accept", "application/json") |> get(~p"/api/posts")
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end

    test "a wrong token is refused", %{conn: conn} do
      conn = conn |> authed("chute") |> get(~p"/api/posts")
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end

    test "the right token lists posts", %{conn: conn, author: author} do
      post = Fixtures.post(%{author: author})
      conn = conn |> authed() |> get(~p"/api/posts")

      assert %{"ok" => true, "posts" => posts} = json_response(conn, 200)
      assert Enum.any?(posts, &(&1["slug"] == post.slug and &1["status"] == "published"))
    end
  end

  describe "writing a draft" do
    test "a new slug creates a draft, and the slug in the URL wins", %{conn: conn, author: author} do
      conn = conn |> authed() |> put(~p"/api/posts/pela-api", %{"markdown" => @markdown})

      assert %{"ok" => true, "created" => true, "post" => body} = json_response(conn, 201)
      assert body["slug"] == "pela-api"
      assert body["status"] == "draft"
      assert body["preview_url"] =~ ~r{/editor/\d+/previa$}

      saved = Content.get_post_by_slug("pela-api")
      assert saved.title == "Um texto pela API"
      assert saved.status == "draft"
      assert saved.author_id == author.id
      assert saved.topics == ["api", "cli"]
      assert saved.reading_minutes >= 1

      assert [%{"type" => "text"}, %{"type" => "section"}, %{"type" => "text"}] =
               saved.body["blocks"]

      refute Content.get_post_by_slug("outro-endereco")
    end

    test "an existing slug is updated, hero and language included", %{conn: conn} do
      conn |> authed() |> put(~p"/api/posts/pela-api", %{"markdown" => @markdown})

      edited = String.replace(@markdown, "Um texto pela API", "Um título novo")

      conn =
        build_conn()
        |> authed()
        |> put(~p"/api/posts/pela-api", %{
          "markdown" => edited,
          "hero" => @hero,
          "language" => "en"
        })

      assert %{"created" => false} = json_response(conn, 200)

      saved = Content.get_post_by_slug("pela-api")
      assert saved.title == "Um título novo"
      assert saved.language == "en"
      assert saved.hero["form"] == "linha_tempo"
      refute Map.has_key?(saved.hero, "type")
    end

    test "updating a published post keeps it published", %{conn: conn, author: author} do
      post = Fixtures.post(%{author: author, slug: "ja-publicado"})

      conn |> authed() |> put(~p"/api/posts/ja-publicado", %{"markdown" => @markdown})

      saved = Content.get_post_by_slug("ja-publicado")
      assert saved.status == "published"
      assert saved.title == "Um texto pela API"
      assert saved.published_at == post.published_at
    end

    test "traducao_de puts the post in the original's translation group", %{conn: conn} do
      conn
      |> authed()
      |> put(~p"/api/posts/original", %{"markdown" => @markdown, "hero" => @hero})

      build_conn() |> authed() |> post(~p"/api/posts/original/publish")

      english = String.replace(@markdown, "marcadores:", "traducao_de: original\nmarcadores:")

      conn =
        build_conn()
        |> authed()
        |> put(~p"/api/posts/the-original", %{
          "markdown" => english,
          "hero" => @hero,
          "language" => "en"
        })

      assert %{"created" => true} = json_response(conn, 201)

      original = Content.get_post_by_slug("original")
      english = Content.get_post_by_slug("the-original")
      assert english.translation_group == original.translation_group
      assert english.language == "en"

      {:ok, _} = Content.publish_post(english)

      conn = build_conn() |> authed() |> get(~p"/api/posts/original")
      assert %{"translations" => %{"en" => "the-original"}} = json_response(conn, 200)["post"]
      refute json_response(conn, 200)["post"]["markdown"] =~ "traducao_de"
    end

    test "traducao_de naming no post is a readable 422", %{conn: conn} do
      md = String.replace(@markdown, "marcadores:", "traducao_de: nada-aqui\nmarcadores:")
      conn = conn |> authed() |> put(~p"/api/posts/x", %{"markdown" => md})
      assert json_response(conn, 422)["error"]["message"] =~ "nada-aqui"
      refute Content.get_post_by_slug("x")
    end

    test "a markdown the dialect refuses comes back as 422 with its message", %{conn: conn} do
      bad = @markdown <> "\n:::diagrama nove\n{}\n:::\n"
      conn = conn |> authed() |> put(~p"/api/posts/pela-api", %{"markdown" => bad})

      assert %{"ok" => false, "error" => %{"code" => "markdown", "message" => message}} =
               json_response(conn, 422)

      assert message =~ "forma de diagrama desconhecida"
      refute Content.get_post_by_slug("pela-api")
    end

    test "a markdown without a title is a readable 422", %{conn: conn} do
      conn = conn |> authed() |> put(~p"/api/posts/sem-titulo", %{"markdown" => "Só texto."})

      assert %{"error" => %{"code" => "invalid", "message" => message, "fields" => fields}} =
               json_response(conn, 422)

      assert message =~ "title"
      assert fields["title"]
    end

    test "a hero outside the seven forms is refused", %{conn: conn} do
      hero = Map.put(@hero, "form", "pizza")

      conn =
        conn
        |> authed()
        |> put(~p"/api/posts/pela-api", %{"markdown" => @markdown, "hero" => hero})

      assert json_response(conn, 422)["error"]["code"] == "hero"
    end

    test "get returns the post as markdown", %{conn: conn} do
      conn |> authed() |> put(~p"/api/posts/pela-api", %{"markdown" => @markdown})

      conn = build_conn() |> authed() |> get(~p"/api/posts/pela-api")
      assert %{"ok" => true, "post" => post} = json_response(conn, 200)
      assert post["markdown"] =~ "titulo: Um texto pela API"
      assert post["markdown"] =~ "endereco: pela-api"
      assert post["hero"] == nil
    end

    test "an unknown slug is 404", %{conn: conn} do
      conn = conn |> authed() |> get(~p"/api/posts/nada-aqui")
      assert json_response(conn, 404)["error"]["code"] == "not_found"
    end
  end

  describe "publishing" do
    test "a draft without a hero is refused and stays a draft", %{conn: conn} do
      conn |> authed() |> put(~p"/api/posts/pela-api", %{"markdown" => @markdown})

      conn = build_conn() |> authed() |> post(~p"/api/posts/pela-api/publish")

      assert %{"error" => %{"code" => "invalid", "fields" => %{"hero" => [_ | _]}}} =
               json_response(conn, 422)

      assert Content.get_post_by_slug("pela-api").status == "draft"
    end

    test "a draft with a hero publishes, and unpublish takes it back", %{conn: conn} do
      conn
      |> authed()
      |> put(~p"/api/posts/pela-api", %{"markdown" => @markdown, "hero" => @hero})

      conn = build_conn() |> authed() |> post(~p"/api/posts/pela-api/publish")

      assert %{"ok" => true, "post" => %{"status" => "published", "url" => url}} =
               json_response(conn, 200)

      assert url =~ ~r{/pela-api$}

      saved = Content.get_post_by_slug("pela-api")
      assert saved.status == "published"
      assert saved.published_at

      conn = build_conn() |> authed() |> post(~p"/api/posts/pela-api/unpublish")
      assert json_response(conn, 200)["post"]["status"] == "draft"
      assert Content.get_post_by_slug("pela-api").status == "draft"
    end
  end
end
