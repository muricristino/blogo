defmodule BlogoWeb.PostControllerTest do
  use BlogoWeb.ConnCase, async: true

  import Blogo.Fixtures

  alias Blogo.Content

  describe "index" do
    test "lists a published post", %{conn: conn} do
      p = post(%{title: "Laya x Jev"})
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Laya x Jev"
      assert html =~ p.author.name
    end

    test "a draft never reaches the index", %{conn: conn} do
      post(%{title: "Rascunho secreto", status: "draft"})
      refute conn |> get(~p"/") |> html_response(200) =~ "Rascunho secreto"
    end
  end

  describe "show" do
    test "renders the post and its structured data", %{conn: conn} do
      p = post(%{title: "Um ensaio medido"})
      html = conn |> get(~p"/#{p.slug}") |> html_response(200)

      assert html =~ "Um ensaio medido"
      assert html =~ ~s(rel="canonical")
      assert html =~ "application/ld+json"
      # The author entity is what makes a name search find the article, so the
      # article has to point at the author page's @id and not just a string.
      assert html =~ "/autor/#{p.author.slug}#person"
    end

    test "a draft is not reachable by slug", %{conn: conn} do
      p = post(%{status: "draft"})
      assert conn |> get(~p"/#{p.slug}") |> response(404)
    end
  end

  describe "the figure on the featured card" do
    setup do
      %{
        featured:
          post(%{
            title: "O destaque",
            hero: %{
              "form" => "fluxo",
              "data" => %{"steps" => []},
              "alt" => "Dois caminhos medidos"
            }
          })
      }
    end

    test "is drawn while the site says so", %{conn: conn, featured: featured} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "feat-fig"
      # The figure itself, not only its container: `alt` is the diagram's
      # aria-label, so this is the drawing being on the page.
      assert html =~ "Dois caminhos medidos"
      assert html =~ featured.title
    end

    test "goes away when the site says not to, and the text takes the room", %{
      conn: conn,
      featured: featured
    } do
      {:ok, _} = Content.update_site(%{"featured_hero" => "false"})
      html = conn |> get(~p"/") |> html_response(200)

      refute html =~ "feat-fig"
      refute html =~ "Dois caminhos medidos"
      # Not the same card with a hole in it: the variant is what widens the
      # column and grows the title.
      assert html =~ "feat--plain"
      assert html =~ featured.title
      assert html =~ "Uma linha de apoio."
    end

    # The switch is about the card above the fold, not about the diagram. The
    # marks beside the other articles are drawn from the same `hero` and stay.
    test "the list keeps the mark beside every other article", %{conn: conn} do
      older =
        post(%{
          title: "Um artigo mais antigo",
          published_at:
            DateTime.add(DateTime.utc_now(), -86_400, :second) |> DateTime.truncate(:second),
          hero: %{"form" => "fluxo", "data" => %{"steps" => []}, "alt" => "A marca da lista"}
        })

      {:ok, _} = Content.update_site(%{"featured_hero" => "false"})
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ older.title
      assert html =~ "A marca da lista"
      refute html =~ "Dois caminhos medidos"
    end

    # Only the home page's layout changed. The figure the article is required to
    # carry is the row, and the article page still points at the card drawn from
    # it — reading the row back is what proves nothing was cleared.
    test "no article loses its hero", %{conn: conn, featured: featured} do
      {:ok, _} = Content.update_site(%{"featured_hero" => "false"})

      assert Content.get_published_by_slug(featured.slug).hero["alt"] ==
               "Dois caminhos medidos"

      html = conn |> get(~p"/#{featured.slug}") |> html_response(200)
      assert html =~ ~s(property="og:image")
      assert html =~ "/imagem/#{featured.slug}.png"
    end

    # The social card is the article's hero rasterised. Off on the home page
    # must not mean off in someone's feed.
    test "the social card is still drawn from the hero", %{conn: conn, featured: featured} do
      {:ok, _} = Content.update_site(%{"featured_hero" => "false"})
      conn = get(conn, "/imagem/#{featured.slug}.png")

      assert ["image/png"] = get_resp_header(conn, "content-type")
      assert <<0x89, "PNG", _::binary>> = response(conn, 200)
    end

    # A published article without a hero has nothing to put in the list, in the
    # feed or on the social card. The home page's layout does not get to say so.
    test "a published article still cannot go without one" do
      {:ok, _} = Content.update_site(%{"featured_hero" => "false"})
      author = author()

      changeset =
        Blogo.Content.Post.changeset(%Blogo.Content.Post{}, %{
          title: "Sem capa",
          slug: "sem-capa-#{System.unique_integer([:positive])}",
          status: "published",
          author_id: author.id,
          hero: nil
        })

      refute changeset.valid?
      assert changeset.errors[:hero]
    end
  end
end
