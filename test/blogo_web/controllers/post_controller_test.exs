defmodule BlogoWeb.PostControllerTest do
  use BlogoWeb.ConnCase, async: true

  import Blogo.Fixtures

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
end
