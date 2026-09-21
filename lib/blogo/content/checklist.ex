defmodule Blogo.Content.Checklist do
  @moduledoc """
  What the editor checks before an article goes out.

  These are the mistakes that are invisible while writing and expensive after
  publishing: a diagram nobody using a screen reader can follow, a figure whose
  caption never got written, a search result that gets truncated mid-sentence.

  Nothing here blocks publishing except the hero, which `Post.changeset/2`
  enforces anyway — the checklist reports, the schema refuses. A writer who
  wants to ship a figure without a caption is allowed to; a writer who does it
  by accident is told.
  """

  alias Blogo.Content.Markdown

  # Google truncates around these, and a result cut mid-word reads as neglect.
  @title_limit 60
  @description_limit 155

  @doc """
  Returns the checks as `{status, text}`, where status is `:ok`, `:warn` or
  `:blocked`. Ordered as the panel shows them: what is wrong first.
  """
  def run(post) do
    blocks = get_in(post, [Access.key(:body, %{}), "blocks"]) || []

    [
      hero(post),
      diagram_alts(blocks),
      figure_captions(blocks),
      summary_numbers(blocks),
      address(post)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {status, _} -> order(status) end)
  end

  defp order(:blocked), do: 0
  defp order(:warn), do: 1
  defp order(:ok), do: 2

  @doc """
  The search-result preview, and whether it fits.
  """
  def search_preview(post) do
    title = to_string(Map.get(post, :title))
    description = to_string(Map.get(post, :meta_description) || Map.get(post, :subtitle))

    %{
      title: title,
      description: description,
      fits?:
        String.length(title) <= @title_limit and String.length(description) <= @description_limit,
      title_limit: @title_limit,
      description_limit: @description_limit
    }
  end

  defp hero(post) do
    case Map.get(post, :hero) do
      %{"form" => f} when is_binary(f) -> {:ok, "O artigo tem o diagrama de capa"}
      _ -> {:blocked, "Falta o diagrama de capa — sem ele o artigo não publica"}
    end
  end

  defp diagram_alts(blocks) do
    diagrams = Enum.filter(blocks, &(&1["type"] == "diagram"))
    missing = Enum.count(diagrams, &(&1["alt"] in [nil, ""]))

    cond do
      diagrams == [] -> nil
      missing == 0 -> {:ok, "Todos os diagramas têm descrição para leitor de tela"}
      true -> {:warn, contagem(missing, "um diagrama sem descrição", "diagramas sem descrição")}
    end
  end

  defp figure_captions(blocks) do
    figures = Enum.filter(blocks, &(&1["type"] in ~w(diagram table code)))
    missing = Enum.count(figures, &(&1["caption"] in [nil, ""]))

    cond do
      figures == [] ->
        nil

      missing == 0 ->
        {:ok, "Toda figura tem legenda"}

      true ->
        {:warn, contagem(missing, "uma figura ainda sem legenda", "figuras ainda sem legenda")}
    end
  end

  # The cover shows an article's key numbers as its summary; without a
  # keynumbers block that space renders empty and the card looks unfinished.
  defp summary_numbers(blocks) do
    if Enum.any?(blocks, &(&1["type"] == "keynumbers")) do
      {:ok, "Há números-chave para o resumo da capa"}
    else
      {:warn, "Nenhum número-chave — o resumo aparece vazio na capa"}
    end
  end

  defp address(post) do
    case Map.get(post, :slug) do
      s when is_binary(s) and s != "" -> nil
      _ -> {:blocked, "Falta o endereço do artigo"}
    end
  end

  # The article decides the gender of the noun, not the count, so the singular
  # is written out in full instead of being assembled from a prefix.
  defp contagem(1, singular, _plural), do: String.capitalize(singular)
  defp contagem(n, _singular, plural), do: "#{n} #{plural}"

  @doc """
  The help line under the markdown editor: which fence opens which block.
  """
  def fence_help do
    Markdown.palette()
    |> Enum.map(fn {type, label, _key} -> {Markdown.fence_name(type), label} end)
    |> Enum.reject(fn {fence, _} -> is_nil(fence) end)
  end
end
