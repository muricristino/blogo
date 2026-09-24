defmodule BlogoWeb.FeedAndTopicTest do
  @moduledoc """
  The two addresses a reader and a crawler reach for that did not exist: the
  feed, and a page per topic. Plus the redirect that keeps an old link working.
  """
  use BlogoWeb.ConnCase

  alias Blogo.{Content, Fixtures}

  # xmerl is the Erlang standard library's XML parser: it raises on anything
  # malformed, so parsing is the assertion.
  #
  # The bytes go in as bytes. `String.to_charlist/1` would hand over decoded
  # codepoints, which xmerl then tries to decode again against the declared
  # utf-8 — and every accent in a Portuguese title fails.
  defp parses_as_xml?(body) do
    try do
      {_doc, _rest} = :xmerl_scan.string(:binary.bin_to_list(body), quiet: true)
      true
    catch
      _, _ -> false
    end
  end

  describe "the feed" do
    test "is well-formed Atom and served as such", %{conn: conn} do
      {:ok, _} = Content.update_site(%{"name" => "Caderno"})
      post = Fixtures.post(%{title: "Um título & um E comercial"})

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert ["application/atom+xml; charset=utf-8"] = get_resp_header(conn, "content-type")
      assert parses_as_xml?(body)

      assert body =~ "<title>Caderno</title>"
      assert body =~ "/#{post.slug}"
      # Reserved characters are escaped, or the document stops being XML.
      assert body =~ "&amp;"
      refute body =~ "& um E"
    end

    test "carries the topics as categories", %{conn: conn} do
      Fixtures.post(%{topics: ["avaliação", "método"]})
      body = conn |> get(~p"/feed.xml") |> response(200)

      assert body =~ ~s(<category term="avaliação"/>)
    end

    test "an empty blog still produces a valid feed", %{conn: conn} do
      body = conn |> get(~p"/feed.xml") |> response(200)
      assert parses_as_xml?(body)
    end

    test "the page points at it, so a reader can discover it", %{conn: conn} do
      Fixtures.post()
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(type="application/atom+xml")
      assert html =~ "/feed.xml"
    end
  end

  describe "topic pages" do
    test "group the articles filed under a term", %{conn: conn} do
      Fixtures.post(%{title: "Primeiro", topics: ["avaliação"]})
      Fixtures.post(%{title: "Segundo", topics: ["avaliação", "método"]})
      Fixtures.post(%{title: "Terceiro", topics: ["postgres"]})

      html = conn |> get(~p"/tag/avaliacao") |> html_response(200)

      assert html =~ "Primeiro"
      assert html =~ "Segundo"
      refute html =~ "Terceiro"
    end

    # The address has to survive an accent: a topic is free text someone typed.
    test "the address folds accents but the page shows the real word", %{conn: conn} do
      Fixtures.post(%{topics: ["produção"]})

      html = conn |> get(~p"/tag/producao") |> html_response(200)
      assert html =~ "produção"
    end

    test "a topic nobody used is a 404, not an empty page", %{conn: conn} do
      Fixtures.post(%{topics: ["avaliação"]})
      assert conn |> get(~p"/tag/inexistente") |> response(404)
    end

    test "a draft's topics do not create a page", %{conn: conn} do
      Fixtures.post(%{status: "draft", topics: ["segredo"]})
      assert conn |> get(~p"/tag/segredo") |> response(404)
    end

    test "they are in the sitemap", %{conn: conn} do
      Fixtures.post(%{topics: ["avaliação"]})
      body = conn |> get(~p"/sitemap.xml") |> response(200)

      assert body =~ "/tag/avaliacao"
    end
  end

  describe "an address that moved" do
    # The editor changes a slug in two clicks. Every link anyone made to the old
    # one used to become a 404 — throwing away what took longest to earn.
    test "answers 301 to the new one", %{conn: conn} do
      post = Fixtures.post(%{slug: "endereco-antigo"})
      {:ok, moved} = Content.save_post(post, %{slug: "endereco-novo"})

      conn = get(conn, ~p"/endereco-antigo")

      assert redirected_to(conn, 301) == "/endereco-novo"
      assert moved.slug == "endereco-novo"
    end

    test "follows the article through two moves", %{conn: conn} do
      post = Fixtures.post(%{slug: "um"})
      {:ok, post} = Content.save_post(post, %{slug: "dois"})
      {:ok, _} = Content.save_post(post, %{slug: "tres"})

      assert conn |> get(~p"/um") |> redirected_to(301) == "/tres"
      assert build_conn() |> get(~p"/dois") |> redirected_to(301) == "/tres"
    end

    # A draft's old address was never public; redirecting to it would say the
    # draft exists.
    test "a draft's former address stays a 404", %{conn: conn} do
      post = Fixtures.post(%{status: "draft", slug: "rascunho-velho"})
      {:ok, _} = Content.save_post(post, %{slug: "rascunho-novo"})

      assert conn |> get(~p"/rascunho-velho") |> response(404)
    end

    test "an address nobody ever used is still a 404", %{conn: conn} do
      assert conn |> get(~p"/nunca-existiu") |> response(404)
    end
  end
end
