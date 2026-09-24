defmodule BlogoWeb.PanelAuthorTest do
  @moduledoc """
  The panel edits the author and manages drafts. Both write, so every test here
  reads the row back from the database — asserting on the rendered page would
  only prove the server agrees with itself.
  """
  use BlogoWeb.ConnCase

  import Ecto.Query
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
    |> Phoenix.ConnTest.post(~p"/auth/login", %{"password" => @password})
    |> Phoenix.ConnTest.recycle()
  end

  defp panel(conn) do
    author = Fixtures.author()
    {:ok, live, _html} = live(sign_in(conn), ~p"/painel")
    # O card começa fechado; o formulário só existe depois de abrir.
    render_click(live, "autor_abrir", %{})
    %{live: live, author: author}
  end

  describe "who signs the blog" do
    test "the name reaches the database", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      live
      |> form("form[phx-submit=autor_salvar]", %{"author" => %{"name" => "Outro Nome"}})
      |> render_submit()

      assert Content.get_author!(author.id).name == "Outro Nome"
    end

    test "headline, bio and city too", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      live
      |> form("form[phx-submit=autor_salvar]", %{
        "author" => %{
          "name" => author.name,
          "headline" => "Escreve sobre o que mede",
          "bio" => "Uma bio nova.",
          "city" => "Campinas"
        }
      })
      |> render_submit()

      saved = Content.get_author!(author.id)
      assert saved.headline == "Escreve sobre o que mede"
      assert saved.bio == "Uma bio nova."
      assert saved.city == "Campinas"
    end

    test "the profiles are stored as a list, one per line", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      live
      |> form("form[phx-submit=autor_salvar]", %{
        "author" => %{
          "name" => author.name,
          "same_as_text" => "https://github.com/muri\nhttps://exemplo.com/muri"
        }
      })
      |> render_submit()

      assert Content.get_author!(author.id).same_as == [
               "https://github.com/muri",
               "https://exemplo.com/muri"
             ]
    end

    # An entry that is not a URL proves nothing to a search engine and is
    # silently ignored there — so it is refused here, where it can be fixed.
    test "a profile that is not an address is refused", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      html =
        live
        |> form("form[phx-submit=autor_salvar]", %{
          "author" => %{"name" => author.name, "same_as_text" => "meu perfil no github"}
        })
        |> render_submit()

      assert html =~ "não é um endereço válido"
      assert Content.get_author!(author.id).same_as == author.same_as
    end

    test "blank lines are dropped rather than stored", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      live
      |> form("form[phx-submit=autor_salvar]", %{
        "author" => %{"name" => author.name, "same_as_text" => "https://exemplo.com\n\n\n"}
      })
      |> render_submit()

      assert Content.get_author!(author.id).same_as == ["https://exemplo.com"]
    end

    test "a name is required", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      live
      |> form("form[phx-submit=autor_salvar]", %{"author" => %{"name" => ""}})
      |> render_submit()

      assert Content.get_author!(author.id).name == author.name
    end

    # The slug sits inside the schema.org `@id` every article points at. It is
    # shown on the panel and not editable there: changing it tells a search
    # engine this is a different person.
    test "the slug cannot be changed through the panel", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      live
      |> render_submit("autor_salvar", %{
        "author" => %{"name" => author.name, "slug" => "outro-endereco"}
      })

      assert Content.get_author!(author.id).slug == author.slug
    end

    test "the new name shows up on the public site", %{conn: conn} do
      %{live: live, author: author} = panel(conn)
      # O artigo tem de ser deste autor: a fixture cria um novo se não disser.
      post = Fixtures.post(%{author: author})

      live
      |> form("form[phx-submit=autor_salvar]", %{"author" => %{"name" => "Nome Publicado"}})
      |> render_submit()

      html = build_conn() |> get(~p"/#{post.slug}") |> html_response(200)
      assert html =~ "Nome Publicado"
    end
  end

  describe "the photo" do
    # The bytes, read back out of Postgres. `:photo` is `load_in_query: false`,
    # so the struct the panel holds does not carry them — which is the point,
    # and also why asserting on it would prove nothing.
    defp stored_photo(author) do
      Blogo.Repo.one(
        from a in Blogo.Content.Author,
          where: a.id == ^author.id,
          select: %{data: a.photo, type: a.photo_type, digest: a.photo_digest}
      )
    end

    defp pick(live, name, content, type \\ "image/png") do
      live
      |> file_input("#pn-foto-form", :foto, [%{name: name, content: content, type: type}])
    end

    test "choosing a file puts it in the database, with no Salvar to press", %{conn: conn} do
      %{live: live, author: author} = panel(conn)
      bytes = Fixtures.png()

      render_upload(pick(live, "eu.png", bytes), "eu.png")

      saved = stored_photo(author)
      assert saved.data == bytes
      assert saved.type == "image/png"
      assert saved.digest
    end

    # The browser is asked to refuse an oversized file, but the browser is not
    # the guard: the limit is enforced where the bytes are written.
    test "a file past the limit does not reach the database", %{conn: conn} do
      %{live: live, author: author} = panel(conn)
      big = Fixtures.png(Blogo.Content.Author.max_photo_bytes() + 1)

      assert {:error, _} = render_upload(pick(live, "grande.png", big), "grande.png")

      assert stored_photo(author).data == nil
    end

    # The name and the content type come from whoever uploads, so they are not
    # evidence. This file passes the extension check and still is not a photo.
    test "a file that only calls itself a PNG is refused", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      render_upload(pick(live, "eu.png", "<svg onload=alert(1)></svg>"), "eu.png")

      assert stored_photo(author).data == nil
      assert :sys.get_state(live.pid).socket.assigns.flash["error"] =~ "foto"
    end

    test "a second photo replaces the first", %{conn: conn} do
      %{live: live, author: author} = panel(conn)

      render_upload(pick(live, "eu.png", Fixtures.png()), "eu.png")
      first = stored_photo(author)

      render_upload(pick(live, "outra.jpg", Fixtures.jpeg(), "image/jpeg"), "outra.jpg")
      second = stored_photo(author)

      assert second.type == "image/jpeg"
      refute second.digest == first.digest
    end

    test "removing it empties the column rather than leaving a dangling type", %{conn: conn} do
      %{live: live, author: author} = panel(conn)
      render_upload(pick(live, "eu.png", Fixtures.png()), "eu.png")

      render_click(live, "foto_remover", %{})

      assert stored_photo(author) == %{data: nil, type: nil, digest: nil}
    end

    test "the photo saved here is what the article serves", %{conn: conn} do
      %{live: live, author: author} = panel(conn)
      post = Fixtures.post(%{author: author})
      bytes = Fixtures.png()

      render_upload(pick(live, "eu.png", bytes), "eu.png")

      assert build_conn() |> get(~p"/autor/#{author.slug}/foto") |> response(200) == bytes

      assert build_conn() |> get(~p"/#{post.slug}") |> html_response(200) =~
               "/autor/#{author.slug}/foto"
    end
  end

  describe "drafts" do
    setup %{conn: conn} do
      %{conn: sign_in(conn)}
    end

    test "a complete draft publishes from the panel", %{conn: conn} do
      draft = Fixtures.post(%{status: "draft"})
      {:ok, live, _html} = live(conn, ~p"/painel")

      render_click(live, "publicar", %{"id" => to_string(draft.id)})

      published = Content.get_post!(draft.id)
      assert published.status == "published"
      assert published.published_at
    end

    # The refusal has to speak the words the screen uses: the changeset says
    # "hero", which appears nowhere in the interface.
    test "a draft with no cover diagram is refused, in the panel's words", %{conn: conn} do
      draft = Fixtures.post(%{status: "draft", hero: nil})
      {:ok, live, _html} = live(conn, ~p"/painel")

      render_click(live, "publicar", %{"id" => to_string(draft.id)})

      assert :sys.get_state(live.pid).socket.assigns.flash["error"] =~ "diagrama de capa"
      assert Content.get_post!(draft.id).status == "draft"
    end

    test "removing a draft takes two clicks", %{conn: conn} do
      draft = Fixtures.post(%{status: "draft"})
      {:ok, live, _html} = live(conn, ~p"/painel")

      render_click(live, "confirmar_remocao", %{"id" => to_string(draft.id)})
      assert Content.get_post!(draft.id)

      render_click(live, "remover", %{"id" => to_string(draft.id)})
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(draft.id) end
    end

    test "cancelling leaves the draft alone", %{conn: conn} do
      draft = Fixtures.post(%{status: "draft"})
      {:ok, live, _html} = live(conn, ~p"/painel")

      render_click(live, "confirmar_remocao", %{"id" => to_string(draft.id)})
      render_click(live, "cancelar_remocao", %{})

      assert Content.get_post!(draft.id)
    end

    # A published article has an address someone may have linked; deleting it
    # turns that link into a 404 with nothing to put in its place.
    test "a published article is not removed from here", %{conn: conn} do
      post = Fixtures.post()
      {:ok, live, _html} = live(conn, ~p"/painel")

      render_click(live, "remover", %{"id" => to_string(post.id)})

      assert Content.get_post!(post.id)
      assert :sys.get_state(live.pid).socket.assigns.flash["error"] =~ "despublique"
    end

    # Clicando pelo elemento, e não disparando o evento na mão: foi assim que a
    # colisão entre `phx-value-value` e a propriedade nativa do <button> passou
    # despercebida — os dois seletores do painel não funcionavam no navegador.
    test "the filter shows drafts alone", %{conn: conn} do
      draft = Fixtures.post(%{status: "draft", title: "Um rascunho qualquer"})
      published = Fixtures.post(%{title: "Já publicado"})
      {:ok, live, _html} = live(conn, ~p"/painel")

      html = live |> element("button[phx-value-filtro=draft]") |> render_click()

      assert html =~ draft.title
      refute html =~ published.title
    end

    test "a draft untouched for weeks says so", %{conn: conn} do
      old = DateTime.add(DateTime.utc_now(), -40 * 86_400, :second) |> DateTime.truncate(:second)
      draft = Fixtures.post(%{status: "draft", title: "Esquecido"})

      Blogo.Repo.update_all(from(p in Blogo.Content.Post, where: p.id == ^draft.id),
        set: [updated_at: old]
      )

      {:ok, _live, html} = live(conn, ~p"/painel")
      assert html =~ "parado"
    end
  end

  describe "the period selector" do
    # Same collision as the filter: both controls were dead in the browser.
    test "changing the period goes through the button's attributes", %{conn: conn} do
      {:ok, live, _html} = live(sign_in(conn), ~p"/painel")

      live |> element("button[phx-value-periodo='7']") |> render_click()

      assert :sys.get_state(live.pid).socket.assigns.period == 7
    end
  end

  describe "the door" do
    test "the panel is not reachable without a session", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/login"}}} = live(conn, ~p"/painel")
    end
  end
end
