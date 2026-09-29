defmodule BlogoWeb.SEOPersonTest do
  @moduledoc """
  The author as an entity a search engine and a model can hold on to.

  The point of this blog is that the writing makes the name recognisable, so the
  question "who is this person" has to have an answer somewhere a machine reads.
  """
  use BlogoWeb.ConnCase

  alias Blogo.Fixtures

  defp json_ld(html) do
    Regex.scan(~r|<script type="application/ld\+json">(.*?)</script>|s, html,
      capture: :all_but_first
    )
    |> Enum.map(fn [j] -> Jason.decode!(j) end)
  end

  defp about_page(author) do
    Fixtures.post(%{author: author, kind: "pagina", slug: "sobre", title: "Sobre"})
  end

  describe "the Person's identity" do
    # `/autor/:slug` has answered a 302 since the About page became an article.
    # An entity identified by a redirect is one a search engine follows and does
    # not find.
    test "is not the address that redirects", %{conn: conn} do
      author = Fixtures.author()
      post = Fixtures.post(%{author: author})

      [article] = conn |> get(~p"/#{post.slug}") |> html_response(200) |> json_ld()

      refute article["author"]["@id"] =~ "/autor/"
      assert article["author"]["@id"] =~ "#person"
    end

    test "points at the about page when there is one", %{conn: conn} do
      author = Fixtures.author()
      about_page(author)

      [profile] = conn |> get(~p"/sobre") |> html_response(200) |> json_ld()

      assert profile["mainEntity"]["url"] =~ "/sobre"
    end

    # The same `@id` in the article, in the site and on the about page is what
    # makes them one entity rather than three people with the same name.
    test "is the same string everywhere", %{conn: conn} do
      author = Fixtures.author()
      about_page(author)
      post = Fixtures.post(%{author: author})

      [site] = conn |> get(~p"/") |> html_response(200) |> json_ld()
      [profile] = conn |> get(~p"/sobre") |> html_response(200) |> json_ld()
      [article] = conn |> get(~p"/#{post.slug}") |> html_response(200) |> json_ld()

      id = profile["mainEntity"]["@id"]

      assert article["author"]["@id"] == id
      assert site["author"]["@id"] == id
      assert site["publisher"]["@id"] == id
    end
  end

  describe "who is this person" do
    test "the about page answers it, in a sentence", %{conn: conn} do
      author = Fixtures.author(%{name: "Muri Cristino", headline: "Engenheiro de software"})
      about_page(author)

      [profile] = conn |> get(~p"/sobre") |> html_response(200) |> json_ld()
      faq = profile["mainEntityOfPage"]

      assert faq["@type"] == "FAQPage"
      [question] = faq["mainEntity"]
      assert question["name"] == "Quem é Muri Cristino?"
      assert question["acceptedAnswer"]["text"] =~ "Muri Cristino é engenheiro de software"
    end

    # A FAQ answering "X is." helps nobody, and marking up an answer nobody
    # wrote is the thing #15 refused to do for the articles.
    test "and says nothing when the record cannot make a sentence", %{conn: conn} do
      author = Fixtures.author(%{headline: nil, bio: nil, city: nil})
      about_page(author)

      [profile] = conn |> get(~p"/sobre") |> html_response(200) |> json_ld()

      refute profile["mainEntityOfPage"]
    end
  end

  test "the Person says what it writes about, from what it published", %{conn: conn} do
    author = Fixtures.author()
    Fixtures.post(%{author: author, topics: ["observabilidade", "postgres"]})
    about_page(author)

    [profile] = conn |> get(~p"/sobre") |> html_response(200) |> json_ld()

    knows = profile["mainEntity"]["knowsAbout"]
    assert "observabilidade" in knows
    assert "postgres" in knows
  end

  # The defect that motivated this: with the same number of articles in three
  # languages the old counting tied and answered English.
  test "the site does not claim to be written in English", %{conn: conn} do
    [site] = conn |> get(~p"/") |> html_response(200) |> json_ld()

    assert site["inLanguage"] == "pt-BR"
  end
end
