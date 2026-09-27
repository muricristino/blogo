defmodule BlogoWeb.SearchTest do
  @moduledoc """
  The search. There was a magnifying glass in the bar with no handler behind it
  — a control that looks like one and is not, which reads as a broken site
  rather than as a missing feature.
  """
  use BlogoWeb.ConnCase

  alias Blogo.Content
  alias Blogo.Fixtures

  defp article(attrs), do: Fixtures.post(attrs)

  defp body(paragraphs),
    do: %{"blocks" => [%{"type" => "text", "paragraphs" => paragraphs}]}

  describe "what it finds" do
    test "a word from the title" do
      article(%{title: "O índice que o Postgres não usou"})

      assert [found] = Content.search("Postgres")
      assert found.title == "O índice que o Postgres não usou"
    end

    # The whole point: the text is inside a JSONB body, and a search that only
    # reads titles is a search that misses the article it was asked for.
    test "a word that only appears in the body" do
      article(%{title: "Sem pista no título", body: body(["Medimos negativos difíceis."])})

      assert [found] = Content.search("negativos")
      assert found.title == "Sem pista no título"
    end

    test "a topic" do
      article(%{title: "Um texto", topics: ["observabilidade"]})

      assert [_] = Content.search("observabilidade")
    end

    test "a plural finds the singular, because Portuguese" do
      article(%{title: "Um texto", body: body(["Comparei dois classificadores tipados."])})

      assert [_] = Content.search("classificador")
    end

    # Snowball takes `medições` to `mediçõ` and `medição` to `mediçã`, so that
    # pair does not meet. Pinned so the limit is a known one rather than a
    # surprise: typing the word as it appears still finds it.
    test "an irregular plural does not, and the exact word still works" do
      article(%{title: "Um texto", body: body(["Medições de latência pareada."])})

      assert Content.search("medição") == []
      assert [_] = Content.search("medições")
    end

    test "an English word in an English article" do
      article(%{language: "en", title: "The index Postgres refused", body: body(["Measured."])})

      assert [_] = Content.search("measuring")
    end

    test "a quoted phrase is taken as a phrase" do
      article(%{title: "Primeiro", body: body(["negativos difíceis no mesmo prompt"])})
      article(%{title: "Segundo", body: body(["negativos fáceis e casos difíceis"])})

      assert [found] = Content.search(~s("negativos difíceis"))
      assert found.title == "Primeiro"
    end
  end

  describe "what it must not find" do
    test "a draft, because the search is public" do
      article(%{title: "Rascunho secreto", status: "draft", published_at: nil})

      assert Content.search("secreto") == []
    end

    test "a post whose publication date has not arrived" do
      later = DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second)
      article(%{title: "Agendado adiante", status: "published", published_at: later})

      assert Content.search("agendado") == []
    end
  end

  describe "what must not blow up" do
    # The input is a stranger's typing. `plainto_tsquery` raises on stray
    # punctuation, which would be a 500 on the one page built to receive it.
    test "punctuation is not a syntax error" do
      for q <- ["&&&", "a & b", "!", ":*", "'", "((("] do
        assert is_list(Content.search(q)), "blew up on #{inspect(q)}"
      end
    end

    test "an empty search asks the database nothing" do
      assert Content.search("") == []
      assert Content.search("   ") == []
      assert Content.search(nil) == []
    end
  end

  describe "the page" do
    test "opens empty, and says what it searches", %{conn: conn} do
      html = conn |> get(~p"/busca") |> html_response(200)

      assert html =~ "Procura dentro dos artigos"
      assert html =~ ~s(name="q")
    end

    test "a search is an address", %{conn: conn} do
      article(%{title: "O índice que o Postgres não usou"})

      html = conn |> get(~p"/busca?q=Postgres") |> html_response(200)

      assert html =~ "O índice que o Postgres não usou"
      assert html =~ "1 resultado"
    end

    # Nothing found is an answer, not an error: it names what was looked for and
    # offers somewhere to go.
    test "nothing found says so, and offers a way out", %{conn: conn} do
      html = conn |> get(~p"/busca?q=zzzzz") |> html_response(200)

      assert html =~ "Nada encontrado para zzzzz"
      assert html =~ "veja todos os artigos"
    end

    # A results page is a view of content that already has its own addresses.
    test "is not indexed", %{conn: conn} do
      html = conn |> get(~p"/busca?q=x") |> html_response(200)

      assert html =~ ~s(name="robots")
      assert html =~ "noindex"
    end

    test "the magnifying glass in the bar leads here", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(href="/busca")
    end
  end
end
