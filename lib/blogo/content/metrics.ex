defmodule Blogo.Content.Metrics do
  @moduledoc """
  Word count and reading time, derived from the blocks rather than typed.

  Reading time on a blog is usually a number someone made up once and never
  revisited. Here it is computed, so it cannot drift from the article: 200
  words a minute for prose, plus a flat 12 seconds for each figure, table or
  listing, because a reader stops at those and the word count cannot see it.
  """

  @words_per_minute 200
  @seconds_per_figure 12

  @doc """
  Counts the words a reader actually reads.

  Diagram data, block types and table headers are not prose and do not count;
  a caption and a margin note do, because they are read.
  """
  def word_count(blocks) when is_list(blocks) do
    blocks |> Enum.map(&block_words/1) |> Enum.sum()
  end

  def word_count(_), do: 0

  @doc """
  Reading time in whole minutes, never less than one.
  """
  def reading_minutes(blocks) when is_list(blocks) do
    prose = word_count(blocks) / @words_per_minute
    figures = count_figures(blocks) * @seconds_per_figure / 60

    max(round(prose + figures), 1)
  end

  def reading_minutes(_), do: 1

  defp block_words(block) do
    block
    |> readable_strings()
    |> Enum.map(&count/1)
    |> Enum.sum()
  end

  defp readable_strings(%{"type" => "text"} = b), do: (b["paragraphs"] || []) ++ extras(b)
  defp readable_strings(%{"type" => "section"} = b), do: [b["title"]] ++ extras(b)

  defp readable_strings(%{"type" => "table"} = b) do
    cells = (b["rows"] || []) |> List.flatten()
    cells ++ (b["headers"] || []) ++ extras(b)
  end

  defp readable_strings(%{"type" => "callout"} = b), do: [b["title"], b["text"]] ++ extras(b)
  defp readable_strings(%{"type" => "quote"} = b), do: [b["text"], b["cite"]] ++ extras(b)
  defp readable_strings(%{"type" => "question"} = b), do: [b["text"]] ++ extras(b)
  defp readable_strings(%{"type" => "marginnote"} = b), do: [b["text"]]
  defp readable_strings(%{"type" => "source"} = b), do: [b["title"], b["note"]]

  defp readable_strings(%{"type" => "keynumbers"} = b) do
    Enum.flat_map(b["items"] || [], &[&1["value"], &1["label"]])
  end

  # The source of a listing is read at a different speed than prose and counting
  # it as words inflates the estimate; the flat figure charge covers it.
  defp readable_strings(%{"type" => "code"} = b), do: extras(b)
  defp readable_strings(%{"type" => "diagram"} = b), do: extras(b)
  defp readable_strings(_), do: []

  defp extras(b), do: [b["caption"], b["note"]]

  defp count(nil), do: 0

  defp count(s) when is_binary(s) do
    s |> String.split(~r/\s+/, trim: true) |> length()
  end

  defp count(_), do: 0

  defp count_figures(blocks) do
    Enum.count(blocks, &(&1["type"] in ~w(diagram table code)))
  end
end
