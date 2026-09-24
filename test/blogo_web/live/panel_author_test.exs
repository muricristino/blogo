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
