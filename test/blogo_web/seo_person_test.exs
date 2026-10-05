defmodule BlogoWeb.SEOPersonTest do
  use BlogoWeb.ConnCase

  alias Blogo.Fixtures

  defp nodes(html) do
    ~r|<script type="application/ld\+json">(.*?)</script>|s
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn [j] -> Jason.decode!(j) end)
    |> Enum.flat_map(fn
      %{"@graph" => graph} -> graph
      node -> [node]
    end)
  end

  defp of_type(html, type), do: html |> nodes() |> Enum.find(&(&1["@type"] == type))

  defp about_page(author),
    do: Fixtures.post(%{author: author, kind: "pagina", slug: "sobre", title: "Sobre"})

  describe "the Person's identity" do
    test "is not the address that redirects", %{conn: conn} do
      post = Fixtures.post(%{author: Fixtures.author()})

      article = conn |> get(~p"/#{post.slug}") |> html_response(200) |> of_type("Article")

      refute article["author"]["@id"] =~ "/autor/"
      assert article["author"]["@id"] =~ "#person"
    end

    test "points at the about page when there is one", %{conn: conn} do
      about_page(Fixtures.author())

      profile = conn |> get(~p"/sobre") |> html_response(200) |> of_type("ProfilePage")

      assert profile["mainEntity"]["url"] =~ "/sobre"
    end

    test "is the same string everywhere", %{conn: conn} do
      author = Fixtures.author()
      about_page(author)
      post = Fixtures.post(%{author: author})

      site = conn |> get(~p"/") |> html_response(200) |> of_type("WebSite")
      profile = conn |> get(~p"/sobre") |> html_response(200) |> of_type("ProfilePage")
      article = conn |> get(~p"/#{post.slug}") |> html_response(200) |> of_type("Article")

      id = profile["mainEntity"]["@id"]

      assert article["author"]["@id"] == id
      assert site["author"]["@id"] == id
      assert site["publisher"]["@id"] == id
    end
  end

  describe "who is this person" do
    # Search Console reported "mainEntityOfPage not recognised": the FAQ used to
    # hang off that field, which names the page an entity is the subject of and
    # takes nothing else. Two entities in one document are siblings in `@graph`.
    test "the FAQ is a node of its own, not a field of the profile", %{conn: conn} do
      about_page(Fixtures.author())
      html = conn |> get(~p"/sobre") |> html_response(200)

      refute of_type(html, "ProfilePage")["mainEntityOfPage"]
      assert of_type(html, "FAQPage")

      assert [%{"@graph" => _}] =
               Regex.scan(~r|<script type="application/ld\+json">(.*?)</script>|s, html,
                 capture: :all_but_first
               )
               |> Enum.map(fn [j] -> Jason.decode!(j) end)
    end

    test "the about page answers it, in a sentence", %{conn: conn} do
      author = Fixtures.author(%{name: "Muri Cristino", headline: "Engenheiro de software"})
      about_page(author)

      faq = conn |> get(~p"/sobre") |> html_response(200) |> of_type("FAQPage")

      assert [question] = faq["mainEntity"]
      assert question["name"] == "Quem é Muri Cristino?"
      assert question["acceptedAnswer"]["text"] =~ "Muri Cristino é engenheiro de software"
      assert faq["about"]["@id"] =~ "#person"
    end

    test "and says nothing when the record cannot make a sentence", %{conn: conn} do
      about_page(Fixtures.author(%{headline: nil, bio: nil, city: nil}))

      refute conn |> get(~p"/sobre") |> html_response(200) |> of_type("FAQPage")
    end
  end

  test "the Person says what it writes about, from what it published", %{conn: conn} do
    author = Fixtures.author()
    Fixtures.post(%{author: author, topics: ["observabilidade", "postgres"]})
    about_page(author)

    profile = conn |> get(~p"/sobre") |> html_response(200) |> of_type("ProfilePage")

    assert "observabilidade" in profile["mainEntity"]["knowsAbout"]
    assert "postgres" in profile["mainEntity"]["knowsAbout"]
  end

  test "the site does not claim to be written in English", %{conn: conn} do
    site = conn |> get(~p"/") |> html_response(200) |> of_type("WebSite")

    assert site["inLanguage"] == "pt-BR"
  end
end
