defmodule Blogo.Content.TranslationsTest do
  @moduledoc """
  An article in more than one language.

  One row per language, tied by a translation group. Not a table of translated
  fields, because a diagram has words inside it — the hero's labels are the
  article's finding stated in words — and translating field by field would mean
  translating JSON from the inside.
  """
  use Blogo.DataCase

  alias Blogo.Content
  alias Blogo.Fixtures

  defp group_of(post), do: Repo.reload!(post).translation_group

  defp sibling(post, language, attrs \\ %{}) do
    Fixtures.post(
      Map.merge(
        %{language: language, translation_group: group_of(post), author: post.author},
        attrs
      )
    )
  end

  describe "the group" do
    test "a post nobody translated is the only member of its own" do
      a = Fixtures.post()
      b = Fixtures.post()

      assert group_of(a)
      assert group_of(a) != group_of(b)
    end

    test "two versions in the same language cannot share a group" do
      pt = Fixtures.post(%{language: "pt-BR"})

      assert_raise Ecto.ConstraintError, fn ->
        sibling(pt, "pt-BR")
      end
    end
  end

  describe "the listing" do
    setup do
      pt = Fixtures.post(%{language: "pt-BR", title: "Em português"})
      sibling(pt, "en", %{title: "In English"})
      untranslated = Fixtures.post(%{language: "pt-BR", title: "Só em português"})

      %{pt: pt, untranslated: untranslated}
    end

    test "shows the reader's language where it exists" do
      titles = Content.list_published("en") |> Enum.map(& &1.title)

      assert "In English" in titles
      refute "Em português" in titles
    end

    # Filtering by language instead would empty the page until everything is
    # translated, which is worse than showing the original.
    test "falls back to the original where it does not" do
      titles = Content.list_published("en") |> Enum.map(& &1.title)

      assert "Só em português" in titles
    end

    test "never shows the same article twice" do
      groups = Content.list_published("en") |> Enum.map(& &1.translation_group)

      assert groups == Enum.uniq(groups)
    end

    test "a language nobody wrote in gets the originals" do
      titles = Content.list_published("es") |> Enum.map(& &1.title)

      assert "Em português" in titles
      assert "Só em português" in titles
    end
  end

  describe "translations_of/1" do
    test "gives the siblings by language, and not itself" do
      pt = Fixtures.post(%{language: "pt-BR", slug: "original"})
      sibling(pt, "en", %{slug: "the-original"})

      assert Content.translations_of(pt) == %{"en" => "the-original"}
    end

    # `hreflang` pointing at a draft sends a search engine to a 404, and the
    # selector would offer the reader a page that is not there.
    test "leaves out a sibling that is not published" do
      pt = Fixtures.post(%{language: "pt-BR"})
      sibling(pt, "en", %{status: "draft", published_at: nil})

      assert Content.translations_of(pt) == %{}
    end

    test "a post with no siblings has none" do
      assert Content.translations_of(Fixtures.post()) == %{}
    end
  end

  describe "the sitemap's view" do
    # Each version is its own address with its own text: a crawler that never
    # sees the English one cannot index it.
    test "every version is listed, unlike the reader's listing" do
      pt = Fixtures.post(%{language: "pt-BR"})
      sibling(pt, "en")

      all = Content.list_all_published() |> Enum.map(& &1.id)

      assert length(all) == 2
      assert length(Content.list_published("en")) == 1
    end
  end
end
