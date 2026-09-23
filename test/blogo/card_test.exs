defmodule Blogo.CardTest do
  @moduledoc """
  The card is the only thing most people will ever see of an article: it is
  what a link to it looks like in a feed. These check the parts that fail
  silently — a card renders as a valid PNG whether or not its text appeared.
  """
  use Blogo.DataCase

  alias Blogo.{Card, Fixtures}

  describe "the drawing" do
    test "is a PNG of the size every platform scales from" do
      post = Fixtures.post()

      assert {:ok, png} = Card.png(post, post.author)
      assert <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>> = png

      # Width and height live in the IHDR chunk, right after the signature.
      <<_::binary-size(16), width::32, height::32, _::binary>> = png
      assert {width, height} == {1200, 630}
    end

    test "carries the title, the author and the topics" do
      post = Fixtures.post(%{title: "Um título medido", topics: ["avaliação"]})
      svg = Card.svg(post, post.author)

      assert svg =~ "Um título medido"
      assert svg =~ post.author.name
      assert svg =~ "AVALIAÇÃO"
    end

    test "draws the article's own hero, not a placeholder" do
      post =
        Fixtures.post(%{
          hero: %{
            "form" => "distribuicao",
            "data" => %{
              "rows" => [
                %{"title" => "Jev", "auc" => "0,956", "pos_c" => 285, "pos_s" => 28}
              ]
            }
          }
        })

      svg = Card.svg(post, post.author)
      assert svg =~ "0,956"
      assert svg =~ "Jev"
    end

    # A post with no hero cannot be published, but a draft can be previewed and
    # the card must not crash on one.
    test "a post without a hero still produces a card" do
      post = Fixtures.post(%{status: "draft", hero: nil})
      assert {:ok, _png} = Card.png(post, post.author)
    end

    # Diagram data is typed by hand in the editor and reaches the renderer
    # unvalidated. A missing number used to raise inside `bell/3`, which took
    # down the article's public page — not just the card.
    test "incomplete diagram data degrades instead of raising" do
      for {form, data} <- [
            {"distribuicao", %{"rows" => [%{"title" => "só o título"}]}},
            {"fluxo", %{"steps" => [%{}]}},
            {"antes_depois", %{"rows" => [%{"label" => "x"}]}},
            {"matriz", %{"cells" => [%{}]}},
            {"decisao", %{}},
            {"linha_tempo", %{"events" => [%{}, %{}]}},
            {"intervalo", %{"rows" => [%{"label" => "y"}]}}
          ] do
        post = Fixtures.post(%{hero: %{"form" => form, "data" => data}})

        assert {:ok, _png} = Card.png(post, post.author),
               "a forma #{form} quebrou com dados incompletos"
      end
    end

    # The rasteriser has no fonts of its own in a container. If this list is
    # ever empty the cards still render — as images with no text on them.
    test "the fonts it needs are shipped with the application" do
      dir = Application.app_dir(:blogo, "priv/fonts")
      fonts = Path.wildcard(Path.join(dir, "*.ttf"))

      assert length(fonts) >= 2
      assert Enum.any?(fonts, &(Path.basename(&1) =~ "Newsreader"))
      assert Enum.any?(fonts, &(Path.basename(&1) =~ "IBMPlexSans"))
    end
  end

  describe "titles that do not fit" do
    test "a long title wraps instead of running off the edge" do
      assert ["Um título bastante", "comprido que não", "cabe numa linha"] =
               Card.wrap("Um título bastante comprido que não cabe numa linha", 20, 4)
    end

    test "a title longer than the card allows is cut, not overflowed" do
      lines = Card.wrap(String.duplicate("palavra ", 40), 20, 3)

      assert length(lines) == 3
      assert List.last(lines) =~ "…"
    end

    test "a single word longer than the line does not loop forever" do
      assert [word] = Card.wrap("Superlongoverysinglewordwithnobreaks", 10, 4)
      assert word == "Superlongoverysinglewordwithnobreaks"
    end
  end
end
