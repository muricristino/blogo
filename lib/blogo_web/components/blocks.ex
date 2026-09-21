defmodule BlogoWeb.Blocks do
  @moduledoc """
  Renders the block list a post carries in `body`.

  Every block sits in a `.row` — a 640px text column beside a 178px margin
  column — so a block's `note` lands next to the paragraph it qualifies
  instead of interrupting it. Below 1080px the grid collapses to one column
  and the note follows its block.

  Inline markup is a deliberately small dialect (`**bold**`, `*italic*`,
  `` `code` ``) parsed here rather than stored as HTML, so the database never
  holds markup nobody validated and old posts pick up a new design system.
  """
  use Phoenix.Component
  import BlogoWeb.Diagrams, only: [diagram: 1]

  attr :blocks, :list, required: true

  def render_blocks(assigns) do
    ~H"""
    <div :for={block <- @blocks} class="row">
      <.block block={block} />
      <aside :if={block["note"]} class="mnote">{inline(block["note"])}</aside>
      <span :if={is_nil(block["note"])}></span>
    </div>
    """
  end

  attr :block, :map, required: true

  def block(%{block: %{"type" => "text"}} = assigns) do
    ~H"""
    <div class={"prose #{if @block["drop"], do: "drop"}"}>
      <p :for={p <- @block["paragraphs"] || []}>{inline(p)}</p>
    </div>
    """
  end

  def block(%{block: %{"type" => "section"}} = assigns) do
    ~H"""
    <div class="sechead" id={@block["id"]} style="margin-top:14px">
      <span class="secn">{@block["n"]}</span>
      <h2 class="h2">{@block["title"]}</h2>
    </div>
    """
  end

  def block(%{block: %{"type" => "table"}} = assigns) do
    assigns = assign(assigns, :numeric, numeric_columns(assigns.block))

    ~H"""
    <figure>
      <div class="card tbl-wrap">
        <table class="tbl">
          <thead>
            <tr>
              <th
                :for={{h, i} <- Enum.with_index(@block["headers"] || [])}
                scope="col"
                style={i in @numeric && "text-align:right"}
              >
                {h}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @block["rows"] || []}>
              <td :for={{cell, i} <- Enum.with_index(row)} class={i in @numeric && "r"}>
                {inline(cell)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <figcaption :if={@block["caption"]} class="cap">{@block["caption"]}</figcaption>
    </figure>
    """
  end

  def block(%{block: %{"type" => "diagram"}} = assigns) do
    ~H"""
    <figure>
      <div class="card dg-wrap">
        <.diagram form={@block["form"]} data={@block["data"] || %{}} label={@block["alt"] || ""} />
      </div>
      <figcaption :if={@block["caption"]} class="cap">{@block["caption"]}</figcaption>
    </figure>
    """
  end

  def block(%{block: %{"type" => "callout"}} = assigns) do
    ~H"""
    <aside class={"callout callout--#{@block["variant"] || "note"}"}>
      <span class="cmark">
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.4"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <path d="M12 8v5" /><path d="M12 17h.01" />
        </svg>
      </span>
      <div>
        <p :if={@block["title"]} class="ctitle">{@block["title"]}</p>
        <p class="ctext">{inline(@block["text"])}</p>
      </div>
    </aside>
    """
  end

  def block(%{block: %{"type" => "code"}} = assigns) do
    ~H"""
    <figure>
      <div class="code">
        <div class="code-head">
          <span class="code-lang">{@block["lang"] || "texto"}</span>
          <button class="code-copy" type="button" data-copy>
            <svg
              width="13"
              height="13"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.9"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <rect x="9" y="9" width="11" height="11" rx="2" /><path d="M5 15V5a2 2 0 0 1 2-2h10" />
            </svg>
            copiar
          </button>
        </div>
        <pre><code><%= @block["source"] %></code></pre>
      </div>
      <figcaption :if={@block["caption"]} class="cap">{@block["caption"]}</figcaption>
    </figure>
    """
  end

  def block(%{block: %{"type" => "quote"}} = assigns) do
    ~H"""
    <blockquote
      class="pull"
      style="border-left:3px solid color-mix(in srgb,var(--accent) 40%,transparent);padding-left:20px"
    >
      {inline(@block["text"])}
      <cite
        :if={@block["cite"]}
        class="small"
        style="display:block;margin-top:10px;font-style:normal;font-family:'IBM Plex Sans',sans-serif"
      >
        {@block["cite"]}
      </cite>
    </blockquote>
    """
  end

  def block(%{block: %{"type" => "keynumbers"}} = assigns) do
    ~H"""
    <div
      class="card"
      style="padding:22px 24px;display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:20px"
    >
      <div :for={item <- @block["items"] || []} class="stat">
        <span class="statn">{item["value"]}</span>
        <span class="small">{item["label"]}</span>
      </div>
    </div>
    """
  end

  def block(%{block: %{"type" => "question"}} = assigns) do
    ~H"""
    <aside class="callout callout--note">
      <span class="cmark">
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.2"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <path d="M9.2 9a3 3 0 1 1 4 2.8c-.8.3-1.2 1-1.2 1.8v.4" /><path d="M12 17.5h.01" />
        </svg>
      </span>
      <div>
        <p class="ctitle">Pergunta guardada</p>
        <p class="ctext">{inline(@block["text"])}</p>
      </div>
    </aside>
    """
  end

  def block(%{block: %{"type" => "source"}} = assigns) do
    ~H"""
    <aside style="border-top:1px solid var(--line);padding-top:14px">
      <span class="micro">Origem dos dados</span>
      <p class="small" style="margin-top:6px">
        <a :if={@block["url"]} href={@block["url"]} rel="nofollow noopener">{@block["title"]}</a>
        <span :if={is_nil(@block["url"])} style="color:var(--ink2)">{@block["title"]}</span>
        <span :if={@block["note"]}> — {@block["note"]}</span>
      </p>
    </aside>
    """
  end

  # A marginnote with no block of its own still belongs in the margin column.
  def block(%{block: %{"type" => "marginnote"}} = assigns) do
    ~H"""
    <aside class="mnote">{inline(@block["text"])}</aside>
    """
  end

  def block(assigns), do: ~H""

  # A column is right-aligned only when every cell in it reads as a number.
  # Aligning a text column right is the tell of a table built by a machine.
  defp numeric_columns(%{"rows" => rows}) when is_list(rows) and rows != [] do
    width = rows |> Enum.map(&length/1) |> Enum.max()

    for i <- 0..(width - 1),
        Enum.all?(rows, fn row -> row |> Enum.at(i) |> numeric?() end),
        do: i
  end

  defp numeric_columns(_), do: []

  defp numeric?(v) when is_binary(v),
    do:
      Regex.match?(
        ~r/^[\s]*[<>~]?[\s]*(US\$|R\$)?[\s]*[\d.,]+(x|%|\s*(ms|s|min|tokens?))?[\s]*$/u,
        v
      )

  defp numeric?(_), do: false

  def inline(nil), do: ""

  def inline(text) when is_binary(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace(~r/\*\*(.+?)\*\*/s, "<b>\\1</b>")
    |> String.replace(~r/(?<!\*)\*([^*]+?)\*(?!\*)/s, "<em>\\1</em>")
    |> String.replace(~r/`(.+?)`/s, "<code class=\"mono\" style=\"font-size:.9em\">\\1</code>")
    |> Phoenix.HTML.raw()
  end

  def inline(other), do: to_string(other)
end
