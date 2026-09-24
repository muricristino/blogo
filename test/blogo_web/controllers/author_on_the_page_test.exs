defmodule BlogoWeb.AuthorOnThePageTest do
  @moduledoc """
  What the reader sees of the author: the face, and the profiles.

  `same_as` existed before this for the structured data alone, which is a claim
  only a crawler could read. The reader makes the same judgement — is the person
  writing here the person with those accounts — and until now had nothing to
  make it with.
  """
  use BlogoWeb.ConnCase

  alias Blogo.Content
  alias Blogo.Fixtures

  defp author_with_profiles do
    Fixtures.author(%{
      name: "Muri Cristino",
      headline: "Engenheiro de software",
      bio: "Escrevo sobre o que eu meço.",
      city: "Campinas",
      same_as: ["https://github.com/muricristino", "https://exemplo.com.br"]
    })
  end

  describe "the end of the article" do
    test "names who wrote it, with the bio", %{conn: conn} do
      post = Fixtures.post(%{author: author_with_profiles()})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ "Quem escreveu"
      assert html =~ "Escrevo sobre o que eu meço."
      assert html =~ "Campinas"
    end

    # rel="me" is the same statement as sameAs in the form the web checks:
    # Mastodon verifies a profile link against it, and IndieAuth reads it.
    # Without it the links are decoration that happens to point somewhere.
    test "links every profile, with rel=me", %{conn: conn} do
      post = Fixtures.post(%{author: author_with_profiles()})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ ~s(href="https://github.com/muricristino")
      assert html =~ ~s(href="https://exemplo.com.br")
      assert html =~ ~s(rel="me noopener")
    end

    test "says where each profile lives, in words a reader knows", %{conn: conn} do
      post = Fixtures.post(%{author: author_with_profiles()})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ "GitHub"
      # An unlisted host names itself rather than being given an invented label.
      assert html =~ "exemplo.com.br"
    end

    test "an author with no profiles gets no empty list", %{conn: conn} do
      post = Fixtures.post(%{author: Fixtures.author(%{same_as: []})})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      refute html =~ "au-links"
    end
  end

  describe "the page about the author" do
    # The "sobre" page is an ordinary article now, edited like any other, so
    # the photo cannot live in its body: it comes from the author record, and
    # the page shows it whatever someone types into the page.
    test "carries the face and the profiles without depending on its own text", %{conn: conn} do
      author = author_with_profiles()
      {:ok, _} = Content.put_author_photo(author, Fixtures.png())

      page =
        Fixtures.post(%{
          author: author,
          kind: "pagina",
          slug: "sobre",
          body: %{"blocks" => [%{"type" => "text", "paragraphs" => ["Qualquer coisa."]}]}
        })

      html = conn |> get(~p"/#{page.slug}") |> html_response(200)

      assert html =~ "Quem escreve aqui"
      assert html =~ "/autor/#{author.slug}/foto"
      assert html =~ ~s(href="https://github.com/muricristino")
    end
  end

  describe "the face" do
    test "is served from this site, not from somebody else's", %{conn: conn} do
      author = author_with_profiles()
      {:ok, _} = Content.put_author_photo(author, Fixtures.png())
      post = Fixtures.post(%{author: author})
      digest = Content.get_author!(author.id).photo_digest

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ "/autor/#{author.slug}/foto?v=#{String.slice(digest, 0, 12)}"
      refute html =~ "gravatar"
    end

    test "falls back to the initials, not to an empty circle", %{conn: conn} do
      post = Fixtures.post(%{author: Fixtures.author(%{name: "Muri Cristino"})})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ "MC"
      refute html =~ "/foto"
    end

    # A knowledge panel can use a Person with an image; a Person without one is
    # a name.
    test "reaches the Person in the structured data", %{conn: conn} do
      author = author_with_profiles()
      {:ok, _} = Content.put_author_photo(author, Fixtures.png())
      post = Fixtures.post(%{author: author})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      assert [%{"author" => person} | _] =
               ~r|<script type="application/ld\+json">(.*?)</script>|s
               |> Regex.scan(html)
               |> Enum.map(fn [_, body] -> Jason.decode!(body) end)
               |> Enum.filter(&(&1["@type"] == "Article"))

      assert person["image"] == "#{BlogoWeb.Endpoint.url()}/autor/#{author.slug}/foto"
      assert person["sameAs"] == author.same_as
    end

    test "is left out of the Person when there is none", %{conn: conn} do
      post = Fixtures.post(%{author: author_with_profiles()})

      html = conn |> get(~p"/#{post.slug}") |> html_response(200)

      refute html =~ ~s("image":"#{BlogoWeb.Endpoint.url()}/autor/)
    end
  end
end
