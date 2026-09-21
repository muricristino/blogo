defmodule BlogoWeb.EditorLiveTest do
  @moduledoc """
  What the editor has to keep true. The cases are grouped as a reviewer would
  walk them: who gets in, what a writer's keystrokes do to the document, and
  what publishing refuses.
  """
  use BlogoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Blogo.Content
  alias Blogo.Fixtures

  @password "senha-de-teste"

  setup do
    Application.put_env(:blogo, :admin_password, @password)
    on_exit(fn -> Application.delete_env(:blogo, :admin_password) end)
    :ok
  end

  defp sign_in(conn) do
    conn
    |> Phoenix.ConnTest.post(~p"/entrar", %{"password" => @password})
    |> Phoenix.ConnTest.recycle()
  end

  defp draft(attrs \\ %{}) do
    Fixtures.post(
      Map.merge(
        %{
          status: "draft",
          title: "Um rascunho",
          hero: nil,
          body: %{"blocks" => [%{"type" => "text", "paragraphs" => ["Primeiro parágrafo."]}]}
        },
        attrs
      )
    )
  end

  describe "who gets in" do
    test "the editor redirects a visitor who is not signed in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/entrar"}}} = live(conn, ~p"/editor")
    end

    test "a wrong password does not sign anyone in", %{conn: conn} do
      conn = post(conn, ~p"/entrar", %{"password" => "chute"})
      assert html_response(conn, 200) =~ "Senha incorreta"

      assert conn |> recycle() |> get(~p"/editor") |> redirected_to() == "/entrar"
    end

    test "the right password opens the editor", %{conn: conn} do
      conn = sign_in(conn)
      assert {:ok, _live, html} = live(conn, ~p"/editor")
      assert html =~ "Posts"
    end

    # The socket reconnects over a websocket, which never re-runs a plug. If
    # only the plug guarded the editor, this would pass while the door is open.
    test "the live socket is guarded too, not just the request", %{conn: conn} do
      post = draft()
      assert {:error, {:redirect, %{to: "/entrar"}}} = live(conn, ~p"/editor/#{post.id}")
    end
  end

  describe "writing" do
    setup %{conn: conn} do
      %{conn: sign_in(conn), post: draft()}
    end

    test "typing in a block changes that block and nothing else", %{conn: conn, post: post} do
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      uid = first_uid(live)

      render_hook(live, "block_input", %{
        "uid" => uid,
        "field" => "paragraphs",
        "value" => "Texto novo."
      })

      # The block is contenteditable and marked `phx-update="ignore"`, so the
      # server holds the new text and the DOM deliberately does not change —
      # asserting on the rendered HTML here would assert the bug.
      assert %{"paragraphs" => ["Texto novo."]} = first_block(live)
    end

    test "a blank line inside a block becomes a second paragraph", %{conn: conn, post: post} do
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      render_hook(live, "block_input", %{
        "uid" => first_uid(live),
        "field" => "paragraphs",
        "value" => "Um.\n\nDois."
      })

      assert %{"paragraphs" => ["Um.", "Dois."]} = first_block(live)
    end

    test "inserting a block puts it after the selected one", %{conn: conn, post: post} do
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      uid = first_uid(live)
      live |> element("[phx-click=select][phx-value-uid=#{uid}]") |> render_click()
      live |> element(".pitem[phx-value-type=section]") |> render_click()

      assert [%{"type" => "text"}, %{"type" => "section"}] = blocks(live)
    end

    test "a block can be moved and removed", %{conn: conn, post: post} do
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      live |> element(".pitem[phx-value-type=quote]") |> render_click()
      assert [%{"type" => "text"}, %{"type" => "quote"}] = blocks(live)

      [_first, second] = blocks(live)
      render_click(live, "move", %{"uid" => second["_uid"], "dir" => "up"})
      assert [%{"type" => "quote"}, %{"type" => "text"}] = blocks(live)

      render_click(live, "delete", %{"uid" => second["_uid"]})
      assert [%{"type" => "text"}] = blocks(live)
    end

    test "reading time is recomputed, never typed", %{conn: conn, post: post} do
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      long = String.duplicate("palavra ", 800)

      render_hook(live, "block_input", %{
        "uid" => first_uid(live),
        "field" => "paragraphs",
        "value" => long
      })

      render_click(live, "save", %{})

      assert Content.get_post!(post.id).reading_minutes == 4
    end

    test "the two modes agree on the document", %{conn: conn, post: post} do
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      render_click(live, "mode", %{"to" => "markdown"})

      render_hook(live, "markdown_input", %{
        "value" => "---\ntitulo: Escrito em markdown\n---\n\n## 01 Uma seção\n\nUm parágrafo.\n"
      })

      render_click(live, "mode", %{"to" => "rich"})

      assert [%{"type" => "section", "title" => "Uma seção"}, %{"type" => "text"}] = blocks(live)
      assert render(live) =~ "Escrito em markdown"
    end

    # Losing an article to a stray colon is the worst thing this screen could
    # do, so a parse error reports and keeps the previous blocks.
    test "broken markdown reports the problem and keeps the document", %{conn: conn, post: post} do
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      render_click(live, "mode", %{"to" => "markdown"})
      html = render_hook(live, "markdown_input", %{"value" => ":::inventado\nnada\n:::\n"})

      assert html =~ "inventado"
      assert [%{"type" => "text", "paragraphs" => ["Primeiro parágrafo."]}] = blocks(live)
    end
  end

  describe "publishing" do
    setup %{conn: conn} do
      %{conn: sign_in(conn)}
    end

    test "a post without a hero diagram is refused", %{conn: conn} do
      post = draft()
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      html = render_click(live, "publish", %{})

      assert html =~ "hero"
      assert Content.get_post!(post.id).status == "draft"
    end

    test "the checklist says what is missing before the button is pressed", %{conn: conn} do
      post = draft()
      {:ok, _live, html} = live(conn, ~p"/editor/#{post.id}")

      assert html =~ "Falta o diagrama de capa"
    end

    test "a complete post publishes", %{conn: conn} do
      post = draft(%{hero: %{"form" => "fluxo", "data" => %{}, "alt" => "Um fluxo"}})
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      render_click(live, "publish", %{})

      published = Content.get_post!(post.id)
      assert published.status == "published"
      assert published.published_at
    end

    # Re-publishing an edit must not move the article back to the top of the
    # index, nor rewrite a date a reader already saw.
    test "publishing again keeps the original date", %{conn: conn} do
      first = ~U[2026-01-02 10:00:00Z]

      post =
        draft(%{
          hero: %{"form" => "fluxo", "data" => %{}},
          status: "published",
          published_at: first
        })

      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")
      render_click(live, "unpublish", %{})
      render_click(live, "publish", %{})

      assert Content.get_post!(post.id).published_at == first
    end

    test "unpublishing keeps the address reserved", %{conn: conn} do
      post = draft(%{hero: %{"form" => "fluxo", "data" => %{}}, status: "published"})
      {:ok, live, _html} = live(conn, ~p"/editor/#{post.id}")

      render_click(live, "unpublish", %{})

      unpublished = Content.get_post!(post.id)
      assert unpublished.status == "draft"
      assert unpublished.slug == post.slug
    end

    test "a draft is not reachable at its public address", %{conn: conn} do
      post = draft()
      assert conn |> get(~p"/#{post.slug}") |> response(404)
    end

    test "the preview renders the draft and tells robots to stay out", %{conn: conn} do
      post = draft()
      html = conn |> get(~p"/editor/#{post.id}/previa") |> html_response(200)

      assert html =~ "Primeiro parágrafo."
      assert html =~ ~s(name="robots")
      assert html =~ "noindex"
    end
  end

  # ── reading the live view's state ──────────────────────────────────────────

  defp blocks(live), do: :sys.get_state(live.pid).socket.assigns.blocks
  defp first_block(live), do: blocks(live) |> List.first()
  defp first_uid(live), do: first_block(live)["_uid"]
end
