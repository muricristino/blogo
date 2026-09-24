defmodule BlogoWeb.EditorLive.Sheet do
  @moduledoc """
  The writing surface: the same measure, type and blocks as the published page.

  Prose blocks are `contenteditable` under `phx-update="ignore"`, so LiveView
  never patches a node the writer has the caret in.
  """
  use BlogoWeb, :html

  alias Blogo.Content.Markdown

  @doc "The writing surface."
  def sheet(assigns) do
    ~H"""
    <div class="ed-center">
      <div class="sheet">
        <form id="ed-head" phx-change="head" style="display:flex;flex-direction:column;gap:14px">
          <span class="micro" style="color:var(--accent)">
            {@fields.kind}
            <span :if={@fields.topics != []}>· {Enum.join(@fields.topics, " · ")}</span>
          </span>

          <label style="display:block">
            <span class="sr-only">Título do post</span>
            <textarea
              id="ed-title"
              phx-hook="Grow"
              class="t-title"
              rows="1"
              name="title"
              phx-debounce="400"
              placeholder="O título"
            >{@fields.title}</textarea>
          </label>

          <label style="display:block">
            <span class="sr-only">Linha de apoio</span>
            <textarea
              id="ed-dek"
              phx-hook="Grow"
              class="t-dek"
              rows="2"
              name="subtitle"
              phx-debounce="400"
              placeholder="A linha que diz o que o leitor ganha"
            >{@fields.subtitle}</textarea>
          </label>
        </form>

        <hr style="border:0;border-top:1px solid var(--line);margin:26px 0" />

        <div class="ed-blocks">
          <.editable_block
            :for={block <- @blocks}
            block={block}
            selected={@selected}
            slash_for={@slash_for}
            slash_query={@slash_query}
            slash_at={@slash_at}
          />

          <button type="button" class="ed-add" phx-click="insert" phx-value-type="text">
            + parágrafo
          </button>
        </div>
      </div>

      <p class="small" style="max-width:660px">
        A folha usa a mesma medida, a mesma tipografia e os mesmos blocos da página publicada —
        o que você vê aqui é o que sai.
      </p>
    </div>
    """
  end

  attr :block, :map, required: true
  attr :selected, :string, default: nil
  attr :slash_for, :string, default: nil
  attr :slash_query, :string, default: ""
  attr :slash_at, :integer, default: 0

  defp editable_block(assigns) do
    ~H"""
    <div
      class={["blk t-body", @selected == @block["_uid"] && "blk--sel"]}
      phx-click="select"
      phx-value-uid={@block["_uid"]}
    >
      <span class="handle">
        <button
          type="button"
          class="hbtn"
          phx-click="move"
          phx-value-uid={@block["_uid"]}
          phx-value-dir="up"
          aria-label="Mover para cima"
        >
          ↑
        </button>
        <button
          type="button"
          class="hbtn"
          phx-click="move"
          phx-value-uid={@block["_uid"]}
          phx-value-dir="down"
          aria-label="Mover para baixo"
        >
          ↓
        </button>
        <button
          type="button"
          class="hbtn"
          phx-click="delete"
          phx-value-uid={@block["_uid"]}
          aria-label="Remover bloco"
        >
          ×
        </button>
      </span>

      <.block_body
        block={@block}
        slash_open={@slash_for == @block["_uid"]}
        selected={@selected == @block["_uid"]}
      />

      <.slash_menu
        :if={@slash_for == @block["_uid"]}
        uid={@block["_uid"]}
        query={@slash_query}
        at={@slash_at}
      />

      <.attachment
        :if={@block["type"] in ~w(diagram table code)}
        label="Legenda"
        field="caption"
        value={@block["caption"]}
        uid={@block["_uid"]}
      />
      <.attachment
        label="Nota de margem"
        field="note"
        value={@block["note"]}
        uid={@block["_uid"]}
      />
    </div>
    """
  end

  attr :block, :map, required: true
  attr :slash_open, :boolean, default: false
  attr :selected, :boolean, default: false

  defp block_body(%{block: %{"type" => "text"}} = assigns) do
    ~H"""
    <.rich_text
      uid={@block["_uid"]}
      field="paragraphs"
      class="prose"
      paragraphs={@block["paragraphs"] || [""]}
      placeholder="Escreva, ou digite / para inserir um bloco"
      slash
      slash_open={@slash_open}
    />
    """
  end

  defp block_body(%{block: %{"type" => "section"}} = assigns) do
    ~H"""
    <div class="sechead" style="margin-top:6px">
      <input
        class="secn ed-inline-input mono"
        style="width:34px"
        value={@block["n"]}
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@block["_uid"]}
        phx-value-field="n"
        name="value"
        placeholder="01"
        aria-label="Número da seção"
      />
      <input
        class="h2 ed-inline-input"
        value={@block["title"]}
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@block["_uid"]}
        phx-value-field="title"
        name="value"
        placeholder="Título da seção"
        aria-label="Título da seção"
      />
    </div>
    """
  end

  defp block_body(%{block: %{"type" => "callout"}} = assigns) do
    ~H"""
    <aside class={"callout callout--#{@block["variant"] || "note"}"}>
      <span class="cmark">!</span>
      <div style="flex-grow:1">
        <select
          class="ed-variant"
          phx-change="block_input"
          phx-value-uid={@block["_uid"]}
          phx-value-field="variant"
          name="value"
          aria-label="Tipo do aviso"
        >
          <option
            :for={v <- ~w(note warn bad)}
            value={v}
            selected={(@block["variant"] || "note") == v}
          >
            {variante(v)}
          </option>
        </select>
        <input
          class="ctitle ed-inline-input"
          value={@block["title"]}
          phx-blur="block_input"
          phx-keyup="block_input"
          phx-debounce="400"
          phx-value-uid={@block["_uid"]}
          phx-value-field="title"
          name="value"
          placeholder="Título do aviso"
          aria-label="Título do aviso"
        />
        <.rich_text
          uid={@block["_uid"]}
          field="text"
          class="ctext"
          value={@block["text"]}
          placeholder="O aviso"
        />
      </div>
    </aside>
    """
  end

  defp block_body(%{block: %{"type" => "quote"}} = assigns) do
    ~H"""
    <blockquote class="pull ed-quote">
      <.rich_text uid={@block["_uid"]} field="text" value={@block["text"]} placeholder="A citação" />
      <input
        class="small ed-inline-input"
        value={@block["cite"]}
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@block["_uid"]}
        phx-value-field="cite"
        name="value"
        placeholder="Quem disse"
        aria-label="Atribuição"
      />
    </blockquote>
    """
  end

  defp block_body(%{block: %{"type" => "question"}} = assigns) do
    ~H"""
    <aside class="callout callout--note">
      <span class="cmark">?</span>
      <div style="flex-grow:1">
        <p class="ctitle">Pergunta guardada</p>
        <.rich_text
          uid={@block["_uid"]}
          field="text"
          class="ctext"
          value={@block["text"]}
          placeholder="A pergunta que ficou"
        />
      </div>
    </aside>
    """
  end

  defp block_body(%{block: %{"type" => "marginnote"}} = assigns) do
    ~H"""
    <.rich_text
      uid={@block["_uid"]}
      field="text"
      class="mnote"
      value={@block["text"]}
      placeholder="A nota que vai na margem"
    />
    """
  end

  defp block_body(%{block: %{"type" => "code"}} = assigns) do
    ~H"""
    <div class="code">
      <div class="code-head">
        <input
          class="code-lang ed-inline-input"
          value={@block["lang"]}
          phx-blur="block_input"
          phx-keyup="block_input"
          phx-debounce="400"
          phx-value-uid={@block["_uid"]}
          phx-value-field="lang"
          name="value"
          placeholder="bash"
          aria-label="Linguagem"
          style="color:rgb(255 255 255/.7)"
        />
      </div>
      <textarea
        class="ed-code"
        rows={max(length(String.split(@block["source"] || "", "\n")), 3)}
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@block["_uid"]}
        phx-value-field="source"
        name="value"
        placeholder="O código"
      >{@block["source"]}</textarea>
    </div>
    """
  end

  defp block_body(%{block: %{"type" => "source"}} = assigns) do
    ~H"""
    <aside style="border-top:1px solid var(--line);padding-top:14px">
      <span class="micro">Origem dos dados</span>
      <input
        class="ed-inline-input"
        value={@block["title"]}
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@block["_uid"]}
        phx-value-field="title"
        name="value"
        placeholder="O que é a fonte"
        aria-label="Título da fonte"
      />
      <input
        class="small ed-inline-input mono"
        value={@block["url"]}
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@block["_uid"]}
        phx-value-field="url"
        name="value"
        placeholder="https://…"
        aria-label="Endereço da fonte"
      />
    </aside>
    """
  end

  # Structured blocks are shown as they will look and edited as their own
  # markdown — the same text markdown mode uses, so there is no third
  # representation to learn.
  defp block_body(%{block: %{"type" => type}} = assigns)
       when type in ~w(table diagram keynumbers) do
    assigns = assign(assigns, :source, block_markdown(assigns.block))

    ~H"""
    <div class="ed-structured">
      <div class="ed-structured-render">
        <%!-- Without the caption: the field below is where it is edited, and
              showing it twice reads as a templating accident. --%>
        <BlogoWeb.Blocks.block block={Map.drop(@block, ["_uid", "caption"])} />
      </div>
      <%!-- The source is shown only while the block is selected. Leaving it
            open under every figure doubled the length of the document on a
            phone and filled the screen with JSON nobody was editing. --%>
      <textarea
        :if={@selected}
        class="ed-structured-src mono"
        rows={max(length(String.split(@source, "\n")), 3)}
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@block["_uid"]}
        phx-value-field="_markdown"
        name="value"
        aria-label="Origem do bloco em markdown"
      >{@source}</textarea>
    </div>
    """
  end

  defp block_body(assigns), do: ~H""

  # `phx-update="ignore"` is what makes this safe: without it LiveView would
  # replace the node on the next patch and take the caret with it.
  attr :uid, :string, required: true
  attr :field, :string, required: true
  attr :value, :string, default: nil
  attr :paragraphs, :list, default: nil
  attr :class, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :slash, :boolean, default: false
  attr :slash_open, :boolean, default: false

  defp rich_text(assigns) do
    ~H"""
    <div
      id={"rt-#{@uid}-#{@field}"}
      phx-hook="RichText"
      phx-update="ignore"
      class={"ed-rt #{@class}"}
      contenteditable="true"
      role="textbox"
      aria-multiline="true"
      aria-label={@placeholder}
      data-uid={@uid}
      data-field={@field}
      data-slash={to_string(@slash)}
      data-slash-open={to_string(@slash_open)}
      data-placeholder={@placeholder}
    ><%= if @paragraphs do %><p :for={p <- @paragraphs}>{Phoenix.HTML.raw(BlogoWeb.Blocks.inline(p))}</p><% else %>{Phoenix.HTML.raw(BlogoWeb.Blocks.inline(@value))}<% end %></div>
    """
  end

  attr :uid, :string, required: true
  attr :query, :string, default: ""
  attr :at, :integer, default: 0

  defp slash_menu(assigns) do
    assigns = assign(assigns, :items, slash_matches(assigns.query))

    ~H"""
    <div class="slash" phx-click-away="slash_close">
      <p :if={@query != ""} class="small" style="padding:4px 10px">/{@query}</p>
      <div
        :for={{{type, label, key}, i} <- Enum.with_index(@items)}
        class={["sitem", i == @at && "is-on"]}
        phx-click="insert"
        phx-value-type={type}
        phx-value-after={@uid}
      >
        <span class="g"><.block_icon type={type} /></span>
        {label}
        <span class="pkey">{key}</span>
      </div>
    </div>
    """
  end

  # A caption is a sentence: a one-line input hid the end of every normal one.
  attr :label, :string, required: true
  attr :field, :string, required: true
  attr :value, :string, default: nil
  attr :uid, :string, required: true

  defp attachment(assigns) do
    ~H"""
    <div class={["ed-attach", @value in [nil, ""] && "ed-attach--empty"]}>
      <span class="ed-attach-plus" aria-hidden="true">{if @field == "caption", do: "+", else: "›"}</span>
      <textarea
        id={"att-#{@uid}-#{@field}"}
        phx-hook="Grow"
        class="ed-inline-input small ed-attach-input"
        rows="1"
        phx-blur="block_input"
        phx-keyup="block_input"
        phx-debounce="400"
        phx-value-uid={@uid}
        phx-value-field={@field}
        name="value"
        placeholder={
          if @field == "caption",
            do: "Escreva a legenda — ela deve dizer a conclusão, não o que a figura é",
            else: "Nota de margem"
        }
        aria-label={@label}
      >{@value}</textarea>
    </div>
    """
  end

  @doc "The little mark beside a block name in the palette."
  def block_icon(assigns) do
    ~H"""
    <svg
      width="15"
      height="15"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <%= case @type do %>
        <% "text" -> %>
          <path d="M4 7h16M4 12h16M4 17h10" />
        <% "section" -> %>
          <path d="M5 5v14M5 12h9M19 8v8" />
        <% "table" -> %>
          <rect x="3" y="5" width="18" height="14" rx="2" /><path d="M3 10h18M9 10v9" />
        <% "diagram" -> %>
          <path d="M4 19V9M10 19V5M16 19v-7M22 19H2" />
        <% "callout" -> %>
          <circle cx="12" cy="12" r="9" /><path d="M12 8v5M12 16h.01" />
        <% "code" -> %>
          <path d="m9 8-5 4 5 4M15 8l5 4-5 4" />
        <% "quote" -> %>
          <path d="M8 7v5a4 4 0 0 1-4 4M18 7v5a4 4 0 0 1-4 4" />
        <% "keynumbers" -> %>
          <path d="M4 8h4M4 16h4M14 6v12M20 6v12" />
        <% "marginnote" -> %>
          <path d="M4 6h10M4 12h10M4 18h6M19 6v12" />
        <% "question" -> %>
          <circle cx="12" cy="12" r="9" /><path d="M9.5 9.5a2.5 2.5 0 1 1 3 2.4v1M12 16h.01" />
        <% "source" -> %>
          <path d="M10 13a5 5 0 0 0 7 0l2-2a5 5 0 0 0-7-7l-1 1" /><path d="M14 11a5 5 0 0 0-7 0l-2 2a5 5 0 0 0 7 7l1-1" />
        <% _ -> %>
          <circle cx="12" cy="12" r="8" />
      <% end %>
    </svg>
    """
  end

  defp variante("note"), do: "nota"
  defp variante("warn"), do: "atenção"
  defp variante("bad"), do: "erro"

  defp block_markdown(block) do
    %{body: %{"blocks" => [Map.delete(block, "_uid")]}}
    |> Markdown.to_markdown()
    |> String.split("---\n\n", parts: 2)
    |> List.last()
    |> String.trim()
  end

  @doc "The palette entries matching what was typed after the slash."
  def slash_matches(""), do: Markdown.palette()

  def slash_matches(query) do
    q = String.downcase(query)

    Enum.filter(Markdown.palette(), fn {_type, label, key} ->
      String.starts_with?(String.trim_leading(key, "/"), q) or
        String.contains?(String.downcase(label), q)
    end)
  end
end
