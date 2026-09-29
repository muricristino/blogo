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

  describe "the language the blog writes in" do
    # It used to be counted from the published posts. With the same number of
    # articles in three languages the count ties, and it answered English — so
    # every page told a search engine that a Portuguese blog is English, and
    # `x-default` pointed at the English version of everything. A tie in a
    # derived number is not a decision anyone made.
    test "is declared, not counted" do
      author = Fixtures.author()
      for _ <- 1..5, do: Fixtures.post(%{author: author, language: "en"})
      Fixtures.post(%{author: author, language: "pt-BR"})

      assert Content.site_language() == "pt-BR"
    end

    test "and the interface's default is the same decision" do
      assert BlogoWeb.Locale.tag(BlogoWeb.Locale.default()) == Content.site_language()
    end

    test "an installation that declares another one gets it" do
      original = Application.get_env(:blogo, :default_language)
      Application.put_env(:blogo, :default_language, "en")
      on_exit(fn -> Application.put_env(:blogo, :default_language, original) end)

      assert Content.site_language() == "en"
      assert BlogoWeb.Locale.default() == "en"
    end
  end
end
