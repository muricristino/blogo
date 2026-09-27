defmodule Blogo.Content.SummaryTest do
  @moduledoc """
  What gets lifted to the "Em resumo" card at the top of an article.

  It used to be the first `keynumbers` block and nothing else, so an article
  with no number worth showing either had no summary or had one invented for it.
  A quote does the same job without claiming a precision the text does not have.
  """
  use ExUnit.Case, async: true

  alias Blogo.Content.Post

  defp post(blocks), do: %Post{body: %{"blocks" => blocks}}

  defp text(t), do: %{"type" => "text", "paragraphs" => [t]}

  defp numbers,
    do: %{"type" => "keynumbers", "items" => [%{"value" => "2", "label" => "portões"}]}

  defp quote_block, do: %{"type" => "quote", "text" => "Fluência é fácil de fingir."}

  test "numbers still become the summary" do
    {summary, blocks} = Post.for_reading(post([text("Antes."), numbers(), text("Depois.")]))

    assert summary["type"] == "keynumbers"
    assert length(blocks) == 2
  end

  test "a quote becomes the summary too" do
    {summary, blocks} = Post.for_reading(post([text("Antes."), quote_block(), text("Depois.")]))

    assert summary["type"] == "quote"
    assert summary["text"] == "Fluência é fácil de fingir."
    assert length(blocks) == 2
  end

  # The one promoted leaves the flow, for the same reason the hero does not
  # repeat in the body: the same thing twice reads as a templating accident.
  test "the promoted block leaves the text" do
    {_summary, blocks} = Post.for_reading(post([quote_block(), text("Depois.")]))

    refute Enum.any?(blocks, &(&1["type"] == "quote"))
  end

  test "whichever comes first wins, and only one is taken" do
    {summary, blocks} = Post.for_reading(post([quote_block(), numbers(), text("Fim.")]))

    assert summary["type"] == "quote"
    assert Enum.any?(blocks, &(&1["type"] == "keynumbers")), "the second one stays in the text"
  end

  test "an article with neither has no summary card" do
    {summary, blocks} = Post.for_reading(post([text("Só texto.")]))

    assert summary == nil
    assert length(blocks) == 1
  end

  # A quote further down is an ordinary pull quote and must not be yanked to the
  # top — but the rule is "the first one", so this pins the consequence: an
  # article whose only quote is its closing line loses it from that position.
  test "the first quote is the one taken, wherever it is" do
    {summary, blocks} = Post.for_reading(post([text("Um."), text("Dois."), quote_block()]))

    assert summary["type"] == "quote"
    assert length(blocks) == 2
  end
end
