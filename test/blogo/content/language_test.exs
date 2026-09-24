defmodule Blogo.Content.LanguageTest do
  @moduledoc """
  The language a post is written in, which is data about the post and not about
  whoever is reading it.
  """
  use Blogo.DataCase

  alias Blogo.Content
  alias Blogo.Content.Post
  alias Blogo.Fixtures

  test "a post written without saying so is in Portuguese" do
    assert Fixtures.post().language == "pt-BR"
  end

  test "a language the site cannot render is refused rather than stored" do
    changeset = Post.changeset(%Post{}, %{language: "fr"})

    assert "is invalid" in errors_on(changeset).language
  end

  test "the blog's own language is the one most of its posts are in" do
    assert Content.site_language() == "pt-BR"

    author = Fixtures.author()
    Fixtures.post(%{author: author, language: "en"})
    Fixtures.post(%{author: author, language: "en"})
    Fixtures.post(%{author: author, language: "pt-BR"})

    assert Content.site_language() == "en"
  end

  test "a draft does not decide what language the blog writes in" do
    author = Fixtures.author()
    Fixtures.post(%{author: author, language: "pt-BR"})

    Fixtures.post(%{
      author: author,
      language: "en",
      status: "draft",
      hero: nil,
      published_at: nil
    })

    assert Content.site_language() == "pt-BR"
  end
end
