defmodule BlogoWeb.ArticleGridTest do
  @moduledoc """
  The article page is a two-column grid: a 220px rail for the table of contents,
  then the text. The aside that fills the rail is conditional, so on a page with
  no sections the article itself became the first grid item and the whole text
  was laid out in 220px — handles running one letter per line, and nothing
  overflowing to say so. Only above 1080px, where the audit did not look.
  """
  use BlogoWeb.ConnCase

  alias Blogo.Fixtures

  defp sectioned_body do
    %{
      "blocks" => [
        %{"type" => "section", "n" => "01", "title" => "Primeira parte"},
        %{"type" => "text", "paragraphs" => ["Algum texto."]}
      ]
    }
  end

  test "a page with no sections drops the rail", %{conn: conn} do
    post = Fixtures.post(%{kind: "pagina"})

    html = conn |> get(~p"/#{post.slug}") |> html_response(200)

    assert html =~ "article-grid--solo"
    refute html =~ ~s(class="toc-col")
  end

  test "an article with sections keeps the rail and fills it", %{conn: conn} do
    post = Fixtures.post(%{body: sectioned_body()})

    html = conn |> get(~p"/#{post.slug}") |> html_response(200)

    refute html =~ "article-grid--solo"
    assert html =~ "toc-col"
  end

  # An article can be written without a single `section` block, and then it is
  # in exactly the same position as the About page.
  test "an article with no sections drops the rail too", %{conn: conn} do
    post = Fixtures.post()

    html = conn |> get(~p"/#{post.slug}") |> html_response(200)

    assert html =~ "article-grid--solo"
  end

  # `"a #{cond && "b"}"` renders the string "false" when the condition is false,
  # because `#{false}` is "false" while `#{nil}` is "". The class list form does
  # not, and this is what keeps it that way.
  test "the class attribute never carries the word false", %{conn: conn} do
    post = Fixtures.post(%{body: sectioned_body()})

    html = conn |> get(~p"/#{post.slug}") |> html_response(200)

    refute html =~ ~r/class="[^"]*\bfalse\b/
  end
end
