defmodule Blogo.Content.Markdown do
  @moduledoc """
  The text form of a post: front matter plus a body, and back again.

  Both editor modes write the same `body["blocks"]`, which only holds if the
  conversion is lossless — `test/blogo/content/markdown_test.exs` keeps it
  honest.

  ## The dialect

  Standard markdown covers seven of the thirteen blocks — an image is
  `![alt](name.png)` on a line of its own, `name` being the image as the post
  stores it, and a list is lines starting with `- ` or `1. `. The other six use
  a fence
  of three colons with the block's name:

      :::aviso bad O antídoto
      Se os negativos são óbvios, você está medindo se o modelo sabe ler.
      :::

  Two prefixes attach to the block above, because both are properties of a
  block rather than blocks: `+ ` is a caption, `^ ` is the margin note.

  A diagram's fence holds `alt:` and the data as JSON — the one place the text
  form is not prose, so the seven forms stay the only drawing.
  """

  @block_fences %{
    "aviso" => "callout",
    "margem" => "marginnote",
    "pergunta" => "question",
    "origem" => "source",
    "numeros" => "keynumbers",
    "diagrama" => "diagram"
  }

  @image ~r/\A!\[(.*)\]\(([^()\s]*)\)\s*\z/

  @bullet ~r/\A- (.*)\z/
  @ordered ~r/\A(\d{1,9})\. (.*)\z/
  @list_start ~r/\A(- |\d{1,9}\. )/

  @fence_of Map.new(@block_fences, fn {k, v} -> {v, k} end)

  @doc """
  Renders a post as the text a writer edits.

  `image_url:` rewrites each image's name into an address, for a reader of the
  text who is not going to have the post's folder beside it.
  """
  def to_markdown(post, opts \\ []) do
    front = front_matter(post)

    body =
      (get_in(post, [Access.key(:body), "blocks"]) || [])
      |> Enum.map(&image_address(&1, opts[:image_url]))
      |> Enum.map(&block_to_md/1)

    ([front] ++ body)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  @doc """
  Parses the text back into post attrs, or `{:error, reason}` — most often a
  diagram whose JSON does not parse, which is why the message names the block.
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

  defp image_address(%{"type" => "image", "src" => src} = block, fun) when is_function(fun, 1),
    do: Map.put(block, "src", fun.(src))

  defp image_address(block, _fun), do: block

  # ── front matter ──────────────────────────────────────────────────────────

  defp front_matter(post) do
    lines =
      [
        {"titulo", get(post, :title)},
        {"resumo", get(post, :subtitle)},
        {"endereco", get(post, :slug)},
        {"tipo", get(post, :kind)},
        {"marcadores", format_list(get(post, :topics))},
        {"capa", get(post, :cover)},
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

  # Quoting always is simpler to read than quoting sometimes.
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
       kind: kind_from(meta["tipo"]),
       meta_description: meta["busca"],
       topics: parse_list(meta["marcadores"]),
       cover: meta["capa"]
     }
     |> Enum.reject(fn {_k, v} -> is_nil(v) end)
     |> Map.new()}
  end

  # A document written before the rename still says `tipo: ensaio`. Reading it
  # has to keep working, or a markdown file saved yesterday comes back as a kind
  # the schema refuses. Writing always uses the current word.
  defp kind_from(nil), do: "artigo"
  defp kind_from("ensaio"), do: "artigo"
  defp kind_from(tipo), do: tipo

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

  # A source writes its description inside its own fence; the same text again
  # as `^` drew it a second time in the margin.
  defp note_of(%{"type" => "source"}), do: nil
  defp note_of(%{"note" => n}) when is_binary(n) and n != "", do: "^ " <> n
  defp note_of(_), do: nil

  # Several paragraphs carrying a note, a caption or a drop cap are one block,
  # but written plainly they would come back as one block per paragraph with
  # the note on the last. The fence keeps them together; everything else stays
  # plain markdown.
  defp body_of(%{"type" => "text"} = b) do
    paragraphs = b["paragraphs"] || []
    text = paragraphs |> Enum.map(&escape_list_start/1) |> Enum.join("\n\n")
    text = if b["drop"], do: "@capitular\n" <> text, else: text

    if length(paragraphs) > 1 and Enum.any?(~w(drop note caption), &b[&1]),
      do: fence("texto", text),
      else: text
  end

  defp body_of(%{"type" => "list"} = b) do
    items = b["items"] || []

    if b["ordered"] do
      start = list_start(b["start"])

      items
      |> Enum.with_index(start)
      |> Enum.map_join("\n", fn {item, n} -> "#{n}. #{one_line(item)}" end)
    else
      Enum.map_join(items, "\n", &("- " <> one_line(&1)))
    end
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

  defp body_of(%{"type" => "image"} = b) do
    "![" <> to_string(b["alt"]) <> "](" <> to_string(b["src"]) <> ")"
  end

  defp body_of(%{"type" => "code"} = b) do
    "```" <> to_string(b["lang"] || "") <> "\n" <> to_string(b["source"] || b["code"]) <> "\n```"
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
      |> Enum.map_join("\n", fn i ->
        "#{i["value"]} | #{i["label"]}" <> if(i["accent"], do: " | destaque", else: "")
      end)

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

  defp list_start(n) when is_integer(n) and n >= 0, do: n
  defp list_start(_), do: 1

  defp one_line(item), do: item |> to_string() |> String.replace(~r/\s*\n\s*/, " ")

  # A paragraph that happens to open with "- " or "1. " would come back as a
  # list; the backslash is the escape markdown itself uses for that.
  defp escape_list_start(p) do
    case Regex.run(~r/\A(\d{1,9})\. /, p) do
      [_, n] -> n <> "\\. " <> String.replace_prefix(p, n <> ". ", "")
      nil -> if String.starts_with?(p, "- "), do: "\\" <> p, else: p
    end
  end

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

  # Markdown cannot say whether the next paragraph starts a new block. Two plain
  # paragraphs render identically either way, so they merge; one carrying a note,
  # caption or drop cap never does, because those point at a specific paragraph.
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

      interrupts_paragraph?(line, current) ->
        chunk(rest, [line], flush(current, acc))

      true ->
        chunk(rest, [line | current], acc)
    end
  end

  # A list may start right under a paragraph without a blank line, as it does in
  # every other markdown; an ordered one only from 1, so a sentence that wraps
  # onto a line starting with a year and a period stays a sentence.
  defp interrupts_paragraph?(_line, []), do: false

  defp interrupts_paragraph?(line, current) do
    first = List.last(current)

    paragraph? =
      not Regex.match?(@list_start, first) and
        not Enum.any?(
          ["> ", "| ", "## ", ":::", "```", "+ ", "^ ", "!["],
          &String.starts_with?(first, &1)
        )

    paragraph? and (String.starts_with?(line, "- ") or String.starts_with?(line, "1. "))
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

  defp lines_to_block([":::texto" | rest]) do
    {drop, rest} =
      case rest do
        ["@capitular" | rest] -> {true, rest}
        rest -> {false, rest}
      end

    paragraphs =
      rest
      |> Enum.chunk_by(&(String.trim(&1) == ""))
      |> Enum.reject(fn lines -> Enum.all?(lines, &(String.trim(&1) == "")) end)
      |> Enum.map(fn [first | rest] -> Enum.join([unescape_list_start(first) | rest], " ") end)

    block = %{"type" => "text", "paragraphs" => paragraphs}
    {:ok, if(drop, do: Map.put(block, "drop", true), else: block)}
  end

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

  defp lines_to_block(["![" <> _ = line]) do
    case Regex.run(@image, line) do
      [_, alt, src] ->
        {:ok, drop_empty(%{"type" => "image", "src" => src, "alt" => alt}, ["alt"])}

      nil ->
        {:ok, paragraphs([line])}
    end
  end

  defp lines_to_block([first | _] = lines) do
    if Regex.match?(@list_start, first), do: {:ok, list(lines)}, else: plain_block(lines)
  end

  defp plain_block(["@capitular" | rest]),
    do: {:ok, rest |> paragraphs() |> Map.put("drop", true)}

  defp plain_block(lines), do: {:ok, paragraphs(lines)}

  defp paragraphs([first | rest]) do
    %{"type" => "text", "paragraphs" => [Enum.join([unescape_list_start(first) | rest], " ")]}
  end

  defp paragraphs([]), do: %{"type" => "text", "paragraphs" => [""]}

  defp unescape_list_start("\\- " <> rest), do: "- " <> rest

  defp unescape_list_start(line) do
    case Regex.run(~r/\A(\d{1,9})\\\. (.*)\z/, line) do
      [_, n, rest] -> n <> ". " <> rest
      nil -> line
    end
  end

  # Each line with the list's own marker opens an item; any other line
  # continues the item above it, which is how a long item wraps in an editor.
  defp list([first | _] = lines) do
    ordered = Regex.match?(@ordered, first)
    marker = if ordered, do: @ordered, else: @bullet

    {items, start} =
      Enum.reduce(lines, {[], nil}, fn line, {items, start} ->
        case Regex.run(marker, line) do
          [_, n, text] -> {[String.trim(text) | items], start || String.to_integer(n)}
          [_, text] -> {[String.trim(text) | items], start}
          nil -> {continue_item(items, line), start}
        end
      end)

    block = %{"type" => "list", "ordered" => ordered, "items" => Enum.reverse(items)}
    if ordered and start != 1, do: Map.put(block, "start", start), else: block
  end

  defp continue_item([last | rest], line),
    do: [String.trim(last <> " " <> String.trim(line)) | rest]

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
        case line |> String.split("|") |> Enum.map(&String.trim/1) do
          [value, label, "destaque"] ->
            %{"value" => value, "label" => label, "accent" => true}

          [value, label | rest] ->
            %{"value" => value, "label" => Enum.join([label | rest], " | ")}

          [value] ->
            %{"value" => value, "label" => ""}
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

  @doc "The seven diagram forms, by the names the dialect writes them with."
  def forms, do: @forms

  @doc """
  The block names the slash palette offers, in the order the design lists them.
  """
  def palette do
    [
      {"text", "Texto", "/t"},
      {"section", "Título de seção", "/h"},
      {"list", "Lista", "/l"},
      {"table", "Tabela", "/tb"},
      {"image", "Imagem", "/i"},
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
