defmodule Blogo.Content.Markdown do
  @moduledoc """
  The text form of a post: front matter plus a body, and back again.

  The editor has two modes over one document. Rich mode manipulates the block
  list directly; markdown mode edits this text and parses it back. Both write
  the same `body["blocks"]`, so a post can be started in one and finished in
  the other — which only holds if the conversion is lossless, and
  `test/blogo/content/markdown_test.exs` is what keeps it honest.

  ## The dialect

  Standard markdown covers five of the eleven blocks: paragraph, `##` heading,
  pipe table, fenced code and `>` quote. The other six have no markdown of
  their own, so they use a fence of three colons with the block's name — the
  same convention the editor's footer advertises:

      :::aviso bad O antídoto
      Se os negativos são óbvios, você está medindo se o modelo sabe ler.
      :::

  Two prefixes attach to the block above rather than standing alone, because
  both are properties of a block and not blocks themselves:

    * `+ ` is the caption under a figure, table or code listing;
    * `^ ` is the margin note that sits beside the block.

  A diagram carries data no prose can express, so its fence holds `alt:` and
  `legenda:` lines followed by the data as JSON. That JSON is the one place
  where the text form is not prose, and it is deliberate: a hand-drawn diagram
  would be a second drawing to keep in sync with the seven forms.
  """

  @block_fences %{
    "aviso" => "callout",
    "margem" => "marginnote",
    "pergunta" => "question",
    "origem" => "source",
    "numeros" => "keynumbers",
    "diagrama" => "diagram"
  }

  @fence_of Map.new(@block_fences, fn {k, v} -> {v, k} end)

  @doc """
  Renders a post as the text a writer edits.
  """
  def to_markdown(post) do
    front = front_matter(post)
    body = (get_in(post, [Access.key(:body), "blocks"]) || []) |> Enum.map(&block_to_md/1)

    ([front] ++ body)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  @doc """
  Parses the text back into the fields a post is made of.

  Returns `{:ok, attrs}` with `:title`, `:subtitle`, `:topics`, `:kind`,
  `:slug` and `:body`, or `{:error, reason}` when the front matter is
  unreadable — a diagram whose JSON does not parse, most often, which is why
  the message names the block.
  """
  def from_markdown(text) when is_binary(text) do
    {front, body} = split_front_matter(text)

    with {:ok, meta} <- parse_front_matter(front),
         {:ok, blocks} <- parse_blocks(body) do
      {:ok,
       meta
       |> Map.put(:body, %{"blocks" => blocks})}
    end
  end

  # ── front matter ──────────────────────────────────────────────────────────

  defp front_matter(post) do
    lines =
      [
        {"titulo", get(post, :title)},
        {"resumo", get(post, :subtitle)},
        {"endereco", get(post, :slug)},
        {"tipo", get(post, :kind)},
        {"marcadores", format_list(get(post, :topics))},
        {"busca", get(post, :meta_description)}
      ]
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Enum.map(fn {k, v} -> "#{k}: #{escape_scalar(v)}" end)

    Enum.join(["---" | lines] ++ ["---"], "\n")
  end

  defp get(post, key), do: Map.get(post, key)

  defp format_list(nil), do: nil
  defp format_list([]), do: nil
  defp format_list(list) when is_list(list), do: "[" <> Enum.join(list, ", ") <> "]"

  # A value that would start a new fence or span lines cannot go in front
  # matter unquoted; quoting always is simpler to read than quoting sometimes.
  defp escape_scalar(v) do
    s = to_string(v)
    if String.contains?(s, "\n"), do: inspect(s), else: s
  end

  defp split_front_matter(text) do
    case String.split(text, ~r/^---\s*$/m, parts: 3) do
      ["", front, body] -> {front, String.trim_leading(body, "\n")}
      _ -> {"", text}
    end
  end

  defp parse_front_matter(front) do
    meta =
      front
      |> String.split("\n", trim: true)
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ":", parts: 2) do
          [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
          _ -> acc
        end
      end)

    {:ok,
     %{
       title: meta["titulo"],
       subtitle: meta["resumo"],
       slug: meta["endereco"],
       kind: meta["tipo"] || "ensaio",
       meta_description: meta["busca"],
       topics: parse_list(meta["marcadores"])
     }
     |> Enum.reject(fn {_k, v} -> is_nil(v) end)
     |> Map.new()}
  end

  defp parse_list(nil), do: nil

  defp parse_list(v) do
    v
    |> String.trim_leading("[")
    |> String.trim_trailing("]")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # ── blocks → text ─────────────────────────────────────────────────────────

  defp block_to_md(block) do
    [body_of(block), caption_of(block), note_of(block)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp caption_of(%{"caption" => c}) when is_binary(c) and c != "", do: "+ " <> c
  defp caption_of(_), do: nil

  defp note_of(%{"note" => n}) when is_binary(n) and n != "", do: "^ " <> n
  defp note_of(_), do: nil

  defp body_of(%{"type" => "text"} = b) do
    paragraphs = b["paragraphs"] || []
    text = Enum.join(paragraphs, "\n\n")
    if b["drop"], do: "@capitular\n" <> text, else: text
  end

  defp body_of(%{"type" => "section"} = b) do
    n = if b["n"] in [nil, ""], do: "", else: b["n"] <> " "
    "## " <> n <> to_string(b["title"])
  end

  defp body_of(%{"type" => "table"} = b) do
    headers = b["headers"] || []
    rows = b["rows"] || []

    ([row_to_md(headers), row_to_md(Enum.map(headers, fn _ -> "---" end))] ++
       Enum.map(rows, &row_to_md/1))
    |> Enum.join("\n")
  end

  defp body_of(%{"type" => "code"} = b) do
    "```" <> to_string(b["lang"] || "") <> "\n" <> to_string(b["source"]) <> "\n```"
  end

  defp body_of(%{"type" => "quote"} = b) do
    lines = b["text"] |> to_string() |> String.split("\n") |> Enum.map(&("> " <> &1))
    cite = if b["cite"], do: ["> — " <> b["cite"]], else: []
    Enum.join(lines ++ cite, "\n")
  end

  defp body_of(%{"type" => "callout"} = b) do
    head = ["aviso", b["variant"] || "note", b["title"]] |> Enum.reject(&is_nil/1)
    fence(Enum.join(head, " "), to_string(b["text"]))
  end

  defp body_of(%{"type" => "marginnote"} = b), do: fence("margem", to_string(b["text"]))
  defp body_of(%{"type" => "question"} = b), do: fence("pergunta", to_string(b["text"]))

  defp body_of(%{"type" => "source"} = b) do
    head = ["origem", b["url"]] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
    body = [b["title"], b["note"]] |> Enum.reject(&is_nil/1) |> Enum.join("\n")
    fence(head, body)
  end

  defp body_of(%{"type" => "keynumbers"} = b) do
    body =
      (b["items"] || [])
      |> Enum.map_join("\n", fn i -> "#{i["value"]} | #{i["label"]}" end)

    fence("numeros", body)
  end

  defp body_of(%{"type" => "diagram"} = b) do
    lines =
      [
        b["alt"] && "alt: " <> b["alt"],
        Jason.encode!(b["data"] || %{})
      ]
      |> Enum.reject(&is_nil/1)

    fence("diagrama " <> to_string(b["form"]), Enum.join(lines, "\n"))
  end

  defp body_of(_), do: nil

  defp fence(head, body), do: ":::" <> head <> "\n" <> body <> "\n:::"

  defp row_to_md(cells), do: "| " <> Enum.join(cells, " | ") <> " |"

  # ── text → blocks ─────────────────────────────────────────────────────────

  defp parse_blocks(body) do
    body
    |> String.split("\n")
    |> chunk()
    |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
      case chunk_to_block(chunk, acc) do
        {:ok, acc} -> {:cont, {:ok, acc}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, acc |> Enum.reverse() |> merge_paragraphs()}
      err -> err
    end
  end

  # A blank line separates paragraphs, and markdown has no way to say whether
  # the next paragraph starts a new block or continues this one. Two plain
  # paragraphs render identically either way, so they merge; a block carrying a
  # margin note, a caption or a drop cap never does, because those point at one
  # specific paragraph.
  defp merge_paragraphs(blocks) do
    Enum.reduce(blocks, [], fn block, acc ->
      case {acc, block} do
        {[prev | rest], %{"type" => "text"}} ->
          if mergeable?(prev) and mergeable?(block) do
            [Map.put(prev, "paragraphs", prev["paragraphs"] ++ block["paragraphs"]) | rest]
          else
            [block | acc]
          end

        _ ->
          [block | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp mergeable?(%{"type" => "text"} = block),
    do: not Enum.any?(["note", "caption", "drop"], &Map.has_key?(block, &1))

  defp mergeable?(_), do: false

  # Groups lines into chunks: a fence and everything up to its closing line, a
  # code block likewise, and otherwise a run of non-blank lines.
  defp chunk(lines), do: chunk(lines, [], [])

  defp chunk([], current, acc), do: Enum.reverse(flush(current, acc))

  defp chunk([line | rest], current, acc) do
    cond do
      String.trim(line) == "" ->
        chunk(rest, [], flush(current, acc))

      String.starts_with?(line, ":::") and current == [] ->
        {block, rest} = take_until(rest, &(String.trim(&1) == ":::"))
        chunk(rest, [], [[line | block] | flush(current, acc)])

      String.starts_with?(line, "```") and current == [] ->
        {block, rest} = take_until(rest, &String.starts_with?(&1, "```"))
        chunk(rest, [], [[line | block] ++ ["```"] | flush(current, acc)])

      true ->
        chunk(rest, [line | current], acc)
    end
  end

  defp flush([], acc), do: acc
  defp flush(current, acc), do: [Enum.reverse(current) | acc]

  defp take_until(lines, fun), do: take_until(lines, fun, [])

  defp take_until([], _fun, taken), do: {Enum.reverse(taken), []}

  defp take_until([line | rest], fun, taken) do
    if fun.(line), do: {Enum.reverse(taken), rest}, else: take_until(rest, fun, [line | taken])
  end

  # A caption or a margin note belongs to the block before it, so the chunk is
  # folded into the accumulator's head instead of becoming a block.
  defp chunk_to_block(lines, acc) do
    {attach, lines} = split_attachments(lines)

    with {:ok, block} <- lines_to_block(lines) do
      case {block, acc} do
        {nil, [prev | rest]} -> {:ok, [Map.merge(prev, attach) | rest]}
        {nil, []} -> {:ok, acc}
        {block, acc} -> {:ok, [Map.merge(block, attach) | acc]}
      end
    end
  end

  defp split_attachments(lines) do
    {attached, plain} =
      Enum.split_with(lines, &(String.starts_with?(&1, "+ ") or String.starts_with?(&1, "^ ")))

    attach =
      Enum.reduce(attached, %{}, fn
        "+ " <> caption, acc -> Map.put(acc, "caption", caption)
        "^ " <> note, acc -> Map.put(acc, "note", note)
      end)

    {attach, plain}
  end

  defp lines_to_block([]), do: {:ok, nil}

  defp lines_to_block([":::" <> head | rest]) do
    body = Enum.join(rest, "\n")

    case String.split(head, " ", trim: true) do
      [name | args] ->
        case Map.fetch(@block_fences, name) do
          {:ok, type} -> fenced_block(type, args, body)
          :error -> {:error, "bloco desconhecido: :::#{name}"}
        end

      [] ->
        {:error, "um ::: sozinho não abre bloco nenhum — falta o nome depois dele"}
    end
  end

  defp lines_to_block(["```" <> lang | rest]) do
    source = rest |> Enum.reverse() |> tl() |> Enum.reverse() |> Enum.join("\n")
    {:ok, drop_empty(%{"type" => "code", "lang" => lang, "source" => source}, ["lang"])}
  end

  defp lines_to_block(["## " <> heading | _]) do
    case String.split(heading, " ", parts: 2) do
      [n, title] -> if numbered?(n), do: section(n, title), else: section(nil, heading)
      _ -> section(nil, heading)
    end
  end

  defp lines_to_block(["> " <> _ | _] = lines) do
    {cite, text} =
      lines
      |> Enum.map(&String.replace_prefix(&1, "> ", ""))
      |> Enum.split_with(&String.starts_with?(&1, "— "))

    block = %{"type" => "quote", "text" => Enum.join(text, "\n")}

    case cite do
      ["— " <> who | _] -> {:ok, Map.put(block, "cite", who)}
      _ -> {:ok, block}
    end
  end

  defp lines_to_block(["| " <> _ | _] = lines) do
    rows =
      lines
      |> Enum.map(fn line ->
        line
        |> String.trim()
        |> String.trim_leading("|")
        |> String.trim_trailing("|")
        |> String.split("|")
        |> Enum.map(&String.trim/1)
      end)
      |> Enum.reject(&separator_row?/1)

    case rows do
      [headers | body] -> {:ok, %{"type" => "table", "headers" => headers, "rows" => body}}
      [] -> {:ok, nil}
    end
  end

  defp lines_to_block(["@capitular" | rest]),
    do: {:ok, rest |> paragraphs() |> Map.put("drop", true)}

  defp lines_to_block(lines), do: {:ok, paragraphs(lines)}

  defp paragraphs(lines) do
    %{"type" => "text", "paragraphs" => [Enum.join(lines, " ")]}
  end

  defp section(n, title) do
    {:ok, drop_empty(%{"type" => "section", "n" => n, "title" => String.trim(title)}, ["n"])}
  end

  defp numbered?(s), do: Regex.match?(~r/^\d+$/, s)

  defp separator_row?(cells), do: Enum.all?(cells, &Regex.match?(~r/^:?-{2,}:?$/, &1))

  defp fenced_block("callout", [v | _rest], _body) when v not in ~w(note warn bad) do
    {:error, "aviso de tipo desconhecido: #{v}. Use note, warn ou bad."}
  end

  defp fenced_block("callout", args, body) do
    {variant, title} =
      case args do
        [v | rest] when v in ~w(note warn bad) -> {v, Enum.join(rest, " ")}
        rest -> {"note", Enum.join(rest, " ")}
      end

    {:ok,
     drop_empty(
       %{"type" => "callout", "variant" => variant, "title" => title, "text" => body},
       ["title"]
     )}
  end

  defp fenced_block("marginnote", _args, body),
    do: {:ok, %{"type" => "marginnote", "text" => body}}

  defp fenced_block("question", _args, body),
    do: {:ok, %{"type" => "question", "text" => body}}

  defp fenced_block("source", args, body) do
    [title | note] = String.split(body, "\n")

    {:ok,
     drop_empty(
       %{
         "type" => "source",
         "url" => List.first(args),
         "title" => title,
         "note" => Enum.join(note, "\n")
       },
       ["url", "note"]
     )}
  end

  defp fenced_block("keynumbers", _args, body) do
    items =
      body
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        case String.split(line, "|", parts: 2) do
          [value, label] -> %{"value" => String.trim(value), "label" => String.trim(label)}
          [value] -> %{"value" => String.trim(value), "label" => ""}
        end
      end)

    {:ok, %{"type" => "keynumbers", "items" => items}}
  end

  @forms ~w(fluxo distribuicao antes_depois matriz decisao linha_tempo intervalo)

  defp fenced_block("diagram", [form | _], _body) when form not in @forms do
    {:error, "forma de diagrama desconhecida: #{form}. As sete são: #{Enum.join(@forms, ", ")}."}
  end

  defp fenced_block("diagram", [], _body) do
    {:error, "o diagrama precisa de uma forma: :::diagrama <forma>"}
  end

  defp fenced_block("diagram", args, body) do
    {meta, json} =
      body
      |> String.split("\n")
      |> Enum.split_with(&String.starts_with?(&1, "alt: "))

    with {:ok, data} <- decode_data(Enum.join(json, "\n")) do
      {:ok,
       drop_empty(
         %{
           "type" => "diagram",
           "form" => List.first(args),
           "alt" => meta |> List.first() |> strip_prefix("alt: "),
           "data" => data
         },
         ["alt"]
       )}
    end
  end

  defp decode_data(""), do: {:ok, %{}}

  defp decode_data(json) do
    case Jason.decode(json) do
      {:ok, data} when is_map(data) -> {:ok, data}
      _ -> {:error, "os dados do diagrama não são JSON válido"}
    end
  end

  defp strip_prefix(nil, _prefix), do: nil
  defp strip_prefix(s, prefix), do: String.replace_prefix(s, prefix, "")

  # A key whose value is empty would come back as `""` and change the block on
  # the round trip, so it is dropped rather than stored.
  defp drop_empty(map, keys) do
    Enum.reduce(keys, map, fn key, acc ->
      if acc[key] in [nil, ""], do: Map.delete(acc, key), else: acc
    end)
  end

  @doc """
  The block names the slash palette offers, in the order the design lists them.
  """
  def palette do
    [
      {"text", "Texto", "/t"},
      {"section", "Título de seção", "/h"},
      {"table", "Tabela", "/tb"},
      {"diagram", "Diagrama", "/d"},
      {"callout", "Aviso", "/a"},
      {"code", "Código", "/c"},
      {"quote", "Citação", "/q"},
      {"keynumbers", "Números-chave", "/n"},
      {"marginnote", "Nota de margem", "/m"},
      {"question", "Pergunta guardada", "/p"},
      {"source", "Origem dos dados", "/o"}
    ]
  end

  @doc """
  The fence name a block type is written with, for the markdown footer's help.
  """
  def fence_name(type), do: Map.get(@fence_of, type)
end
