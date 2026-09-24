defmodule Blogo.Content.Llms do
  @moduledoc """
  What this site hands a generative model: the map (`llms.txt`) and each
  article's own markdown.

  Nothing here is written by hand. The map is the site's name, its description,
  who signs it and every published article with what that article claims — all
  of it read from the database, so an install that renames itself or publishes
  tomorrow does not have a stale file to remember.

  The article's markdown is `Blogo.Content.Markdown.to_markdown/1`, the same
  text the editor's markdown mode shows, plus three front matter lines a
  consumer needs and a writer does not: the canonical address, the date and who
  wrote it. They are extra keys, which `from_markdown/1` ignores, so the
  document still parses back into the same blocks — `test/blogo/content/llms_test.exs`
  checks exactly that.
  """

  alias Blogo.Content
  alias Blogo.Content.{Crawlers, Markdown, Post}

  @doc """
  The article as the text a model reads, canonical address included.
  """
  def document(%Post{} = post, base_url) do
    post
    |> Markdown.to_markdown()
    |> put_front_matter(
      [
        "canonical: #{base_url}/#{post.slug}",
        post.published_at && "publicado: #{DateTime.to_date(post.published_at)}",
        author_name(post) && "autor: #{author_name(post)}"
      ]
      |> Enum.reject(&is_nil/1)
    )
  end

  defp author_name(%Post{author: %{name: name}}), do: name
  defp author_name(_post), do: nil

  # Inserted before the closing marker rather than appended to the document, so
  # the front matter stays one block. A document without front matter is left
  # alone: corrupting it would be worse than missing the canonical.
  defp put_front_matter(text, extra) do
    case String.split(text, "\n") do
      ["---" | rest] ->
        case Enum.split_while(rest, &(&1 != "---")) do
          {front, ["---" | body]} ->
            Enum.join(["---"] ++ front ++ extra ++ ["---"] ++ body, "\n")

          _ ->
            text
        end

      _ ->
        text
    end
  end

  @doc """
  The map of the site, in the shape llmstxt.org describes: one H1, one
  blockquote, then lists of links.

  Every link points at the `.md` address, because that is what the consumer
  came for, and each entry carries the claim the article makes rather than its
  topic — a list of titles says what exists, not what it would be worth reading
  for.
  """
  def llms_txt(%{site: site, author: author, posts: posts, pages: pages, base_url: base_url}) do
    policy = Crawlers.policy(site)

    ([
       "# #{Content.site_name(site)}",
       ""
     ] ++
       description(site) ++
       author_lines(author) ++
       [
         "Cada artigo tem uma versão em markdown no mesmo endereço, com `.md` no fim.",
         "O endereço para citar é sempre o HTML, sem o `.md`.",
         "Crawler de IA nesta instalação — #{Crawlers.summary(policy)}",
         ""
       ] ++
       article_section(posts, base_url) ++
       page_section(pages, base_url) ++
       [
         "## Optional",
         "",
         "- [Feed Atom](#{base_url}/feed.xml): cada artigo novo, na ordem em que sai.",
         "- [Mapa do site](#{base_url}/sitemap.xml): todo endereço público, com a data da última alteração.",
         ""
       ])
    |> Enum.join("\n")
  end

  defp description(%{description: description})
       when is_binary(description) and description != "" do
    ["> #{description}", ""]
  end

  defp description(_site), do: []

  defp author_lines(nil), do: []

  defp author_lines(author) do
    signature =
      [author.name, author.headline]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(", ")

    bio = if author.bio in [nil, ""], do: [], else: [author.bio]

    perfis =
      case author.same_as do
        [_ | _] = links -> ["Perfis do autor: #{Enum.join(links, " · ")}"]
        _ -> []
      end

    (["Escrito por #{signature}."] ++ bio ++ perfis ++ [""])
    |> Enum.reject(&(&1 == nil))
  end

  defp article_section([], _base_url) do
    ["## Artigos", "", "Nenhum artigo publicado ainda.", ""]
  end

  defp article_section(posts, base_url) do
    ["## Artigos", "", "Do mais recente para o mais antigo."] ++
      [""] ++
      Enum.map(posts, &entry(&1, base_url)) ++
      [""]
  end

  defp page_section([], _base_url), do: []

  defp page_section(pages, base_url) do
    ["## Páginas", "", "Páginas fixas: ficam fora da lista de artigos e do feed."] ++
      [""] ++
      Enum.map(pages, &entry(&1, base_url)) ++
      [""]
  end

  # The claim, then the facts that let a consumer decide whether to fetch it.
  defp entry(post, base_url) do
    claim = post.meta_description || post.subtitle

    facts =
      [
        post.published_at && "publicado em #{DateTime.to_date(post.published_at)}",
        post.reading_minutes && "#{post.reading_minutes} min de leitura",
        post.topics != [] && "marcadores: #{Enum.join(post.topics, ", ")}"
      ]
      |> Enum.filter(&is_binary/1)
      |> Enum.join("; ")

    "- [#{post.title}](#{base_url}/#{post.slug}.md): " <>
      ([claim, facts] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" — "))
  end
end
