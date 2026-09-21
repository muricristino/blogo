defmodule BlogoWeb.EditorLive.Edit do
  @moduledoc """
  The post editor: two modes over one document.

  **Rich** manipulates the block list directly. Prose blocks are
  `contenteditable`, marked `phx-update="ignore"` so LiveView never patches a
  node the writer has the caret in — the one rule that keeps a collaborative
  DOM and a live editor from fighting over the same text.

  **Markdown** edits the whole document as text through
  `Blogo.Content.Markdown`, and parses it back on every keystroke. A parse
  error does not discard the text: it is reported and the last good block list
  stays, because losing an article to a stray colon is unforgivable.

  Autosave runs on a timer that restarts with each change, so a writer in the
  middle of a sentence is not interrupted by a save on every character.
  """
  use BlogoWeb, :live_view

  alias Blogo.Content
  alias Blogo.Content.{Checklist, Markdown, Metrics}

  @autosave_after 1_500

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Content.get_post!(id)

    {:ok,
     socket
     |> assign(
       post: post,
       page_title: post.title,
       editor?: true,
       mode: :rich,
       selected: nil,
       slash_for: nil,
       saved_at: post.updated_at,
       dirty?: false,
       timer: nil,
       error: nil,
       markdown: Markdown.to_markdown(post)
     )
     |> put_blocks(post.body["blocks"] || [])
     |> assign_derived()}
  end

  # ── events ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("select", %{"uid" => uid}, socket) do
    {:noreply, assign(socket, selected: uid, slash_for: nil)}
  end

  def handle_event("block_input", %{"uid" => uid, "field" => field, "value" => value}, socket) do
    blocks =
      update_block(socket.assigns.blocks, uid, fn block ->
        put_field(block, field, value)
      end)

    {:noreply, socket |> put_blocks(blocks) |> touched()}
  end

  def handle_event("insert", %{"type" => type} = params, socket) do
    blocks = insert_after(socket.assigns.blocks, params["after"], new_block(type))

    {:noreply,
     socket
     |> put_blocks(blocks)
     |> assign(slash_for: nil)
     |> touched()}
  end

  def handle_event("move", %{"uid" => uid, "dir" => dir}, socket) do
    {:noreply, socket |> put_blocks(move(socket.assigns.blocks, uid, dir)) |> touched()}
  end

  def handle_event("delete", %{"uid" => uid}, socket) do
    blocks = Enum.reject(socket.assigns.blocks, &(&1["_uid"] == uid))
    {:noreply, socket |> put_blocks(blocks) |> assign(selected: nil) |> touched()}
  end

  def handle_event("slash", %{"uid" => uid}, socket) do
    {:noreply, assign(socket, slash_for: uid, selected: uid)}
  end

  def handle_event("slash_close", _params, socket), do: {:noreply, assign(socket, slash_for: nil)}

  # An input outside a form sends `%{"value" => ...}`, so the field it belongs
  # to travels as a phx-value and is matched against a fixed list — never
  # `String.to_atom` on something that arrived from a browser.
  def handle_event("field", %{"field" => field, "value" => value}, socket) do
    case field do
      f when f in ~w(title subtitle slug kind meta_description) ->
        post = Map.put(socket.assigns.post, String.to_existing_atom(f), value)
        {:noreply, socket |> assign(post: post) |> assign_derived() |> touched()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("add_topic", %{"value" => topic}, socket) do
    topic = String.trim(topic)
    post = socket.assigns.post

    if topic == "" or topic in post.topics do
      {:noreply, socket}
    else
      post = %{post | topics: post.topics ++ [topic]}
      {:noreply, socket |> assign(post: post) |> touched()}
    end
  end

  def handle_event("remove_topic", %{"topic" => topic}, socket) do
    post = socket.assigns.post
    post = %{post | topics: List.delete(post.topics, topic)}
    {:noreply, socket |> assign(post: post) |> touched()}
  end

  def handle_event("mode", %{"to" => "markdown"}, socket) do
    post = post_with_blocks(socket)

    {:noreply, assign(socket, mode: :markdown, markdown: Markdown.to_markdown(post), error: nil)}
  end

  def handle_event("mode", %{"to" => "rich"}, socket) do
    {:noreply, assign(socket, mode: :rich, slash_for: nil)}
  end

  def handle_event("markdown_input", %{"value" => text}, socket) do
    socket = assign(socket, markdown: text)

    case Markdown.from_markdown(text) do
      {:ok, attrs} ->
        post = struct(socket.assigns.post, Map.delete(attrs, :body))

        {:noreply,
         socket
         |> assign(post: post, error: nil)
         |> put_blocks(attrs.body["blocks"])
         |> touched()}

      {:error, message} ->
        # The text stays exactly as typed; only the parsed form is withheld.
        {:noreply, assign(socket, error: message)}
    end
  end

  def handle_event("save", _params, socket), do: {:noreply, save(socket)}

  def handle_event("publish", _params, socket) do
    socket = save(socket)
    post = socket.assigns.post

    case Content.publish_post(post, attrs_of(socket)) do
      {:ok, post} ->
        {:noreply,
         socket
         |> assign(post: post, saved_at: post.updated_at, dirty?: false)
         |> assign_derived()
         |> put_flash(:info, "Publicado em /#{post.slug}")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, first_error(changeset))}
    end
  end

  def handle_event("unpublish", _params, socket) do
    case Content.unpublish_post(socket.assigns.post) do
      {:ok, post} ->
        {:noreply,
         socket
         |> assign(post: post)
         |> assign_derived()
         |> put_flash(:info, "Voltou a rascunho. O endereço /#{post.slug} fica reservado.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, first_error(changeset))}
    end
  end

  @impl true
  def handle_info(:autosave, socket), do: {:noreply, save(socket)}

  # ── saving ────────────────────────────────────────────────────────────────

  defp touched(socket) do
    if socket.assigns.timer, do: Process.cancel_timer(socket.assigns.timer)

    assign(socket,
      dirty?: true,
      timer: Process.send_after(self(), :autosave, @autosave_after)
    )
  end

  defp save(%{assigns: %{dirty?: false}} = socket), do: socket

  defp save(socket) do
    case Content.save_post(socket.assigns.post, attrs_of(socket)) do
      {:ok, post} ->
        socket
        |> assign(post: post, saved_at: post.updated_at, dirty?: false, timer: nil)
        |> assign_derived()

      {:error, changeset} ->
        put_flash(socket, :error, first_error(changeset))
    end
  end

  defp attrs_of(socket) do
    post = socket.assigns.post

    %{
      title: post.title,
      subtitle: post.subtitle,
      slug: post.slug,
      kind: post.kind,
      topics: post.topics,
      meta_description: post.meta_description,
      body: %{"blocks" => clean_blocks(socket.assigns.blocks)}
    }
  end

  defp first_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, [msg | _]} -> "#{field} #{msg}" end)
    |> List.first()
    |> Kernel.||("não foi possível salvar")
  end

  # ── block bookkeeping ─────────────────────────────────────────────────────

  # Each block gets an id that lives only in this session. It is what
  # `phx-update="ignore"` keys on, so it has to be stable while the block
  # exists and unique while two blocks do.
  defp put_blocks(socket, blocks) do
    {blocks, _n} =
      Enum.map_reduce(blocks, 0, fn block, n ->
        case block["_uid"] do
          nil -> {Map.put(block, "_uid", "b#{System.unique_integer([:positive])}"), n + 1}
          _ -> {block, n + 1}
        end
      end)

    socket |> assign(blocks: blocks) |> assign_derived()
  end

  defp clean_blocks(blocks), do: Enum.map(blocks, &Map.delete(&1, "_uid"))

  defp post_with_blocks(socket) do
    %{socket.assigns.post | body: %{"blocks" => clean_blocks(socket.assigns.blocks)}}
  end

  defp update_block(blocks, uid, fun) do
    Enum.map(blocks, fn block ->
      if block["_uid"] == uid, do: fun.(block), else: block
    end)
  end

  # A paragraph field is a list; everything else is a scalar. Splitting on the
  # blank line here means the rich mode produces the same block a markdown
  # paste would.
  defp put_field(block, "paragraphs", value) do
    Map.put(block, "paragraphs", String.split(value, ~r/\n{2,}/, trim: true))
  end

  # A structured block is edited as its own markdown, so what comes back is
  # parsed with the same reader the markdown mode uses. A broken edit keeps the
  # previous block instead of replacing it with nothing.
  defp put_field(block, "_markdown", value) do
    case Markdown.from_markdown(value) do
      {:ok, %{body: %{"blocks" => [parsed | _]}}} -> Map.merge(parsed, %{"_uid" => block["_uid"]})
      _ -> block
    end
  end

  defp put_field(block, field, "") when field in ~w(caption note title cite alt lang),
    do: Map.delete(block, field)

  defp put_field(block, field, value), do: Map.put(block, field, value)

  defp insert_after(blocks, nil, block), do: blocks ++ [block]

  defp insert_after(blocks, uid, block) do
    case Enum.find_index(blocks, &(&1["_uid"] == uid)) do
      nil -> blocks ++ [block]
      i -> List.insert_at(blocks, i + 1, block)
    end
  end

  defp move(blocks, uid, dir) do
    case Enum.find_index(blocks, &(&1["_uid"] == uid)) do
      nil ->
        blocks

      i ->
        target = if dir == "up", do: i - 1, else: i + 1

        if target in 0..(length(blocks) - 1) do
          block = Enum.at(blocks, i)
          blocks |> List.delete_at(i) |> List.insert_at(target, block)
        else
          blocks
        end
    end
  end

  defp new_block(type) do
    base = %{"_uid" => "b#{System.unique_integer([:positive])}", "type" => type}

    Map.merge(base, defaults(type))
  end

  defp defaults("text"), do: %{"paragraphs" => [""]}
  defp defaults("section"), do: %{"title" => "Nova seção"}
  defp defaults("table"), do: %{"headers" => ["Coluna", "Valor"], "rows" => [["", ""]]}
  defp defaults("diagram"), do: %{"form" => "fluxo", "data" => %{"steps" => []}, "alt" => ""}
  defp defaults("callout"), do: %{"variant" => "note", "title" => "", "text" => ""}
  defp defaults("code"), do: %{"lang" => "bash", "source" => ""}
  defp defaults("quote"), do: %{"text" => ""}
  defp defaults("keynumbers"), do: %{"items" => [%{"value" => "", "label" => ""}]}
  defp defaults("question"), do: %{"text" => ""}
  defp defaults("source"), do: %{"title" => "", "url" => ""}
  defp defaults("marginnote"), do: %{"text" => ""}
  defp defaults(_), do: %{}

  defp assign_derived(socket) do
    blocks = clean_blocks(socket.assigns[:blocks] || [])
    post = %{socket.assigns.post | body: %{"blocks" => blocks}}

    assign(socket,
      words: Metrics.word_count(blocks),
      minutes: Metrics.reading_minutes(blocks),
      checklist: Checklist.run(post),
      search: Checklist.search_preview(post)
    )
  end

  # ── render ────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="lx-admin" phx-window-keydown="slash_close" phx-key="Escape">
      <.topbar {assigns} />

      <div class={"ed-grid ed-grid--#{@mode}"}>
        <.palette :if={@mode == :rich} selected={@selected} />
        <.sheet :if={@mode == :rich} {assigns} />
        <.markdown_pane :if={@mode == :markdown} {assigns} />
        <.preview_pane :if={@mode == :markdown} {assigns} />
        <.side :if={@mode == :rich} {assigns} />
      </div>
    </div>
    """
  end

  defp topbar(assigns) do
    ~H"""
    <nav class="bar ed-bar">
      <div style="display:flex;align-items:center;gap:12px;min-width:0">
        <.link class="iconbtn" navigate={~p"/editor"} aria-label="Voltar aos posts">
          <svg
            width="17"
            height="17"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.9"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="m14 6-6 6 6 6" />
          </svg>
        </.link>
        <span style="display:flex;flex-direction:column;gap:1px;min-width:0">
          <span class="small" style="font-size:11.5px">
            <.link class="ed-crumb" navigate={~p"/editor"}>Posts</.link> / {estado(@post.status)}
          </span>
          <span class="ed-title">{@post.title}</span>
        </span>
      </div>

      <span class="saved">
        <svg
          :if={not @dirty?}
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
          style="color:var(--good)"
        >
          <path d="m5 13 4 4L19 7" />
        </svg>
        {if @dirty?, do: "salvando…", else: "salvo #{ha_quanto(@saved_at)}"}
      </span>

      <div class="ed-actions">
        <span class="small mono ed-count">{format_int(@words)} palavras · {@minutes} min</span>

        <span class="seg2">
          <button
            type="button"
            class={@mode == :rich && "is-on"}
            phx-click="mode"
            phx-value-to="rich"
          >
            Rico
          </button>
          <button
            type="button"
            class={@mode == :markdown && "is-on"}
            phx-click="mode"
            phx-value-to="markdown"
          >
            Markdown
          </button>
        </span>

        <a
          class="btn btn--s"
          href={~p"/editor/#{@post.id}/previa"}
          target="_blank"
          rel="noopener"
        >
          <svg
            width="15"
            height="15"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            aria-hidden="true"
          >
            <path d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z" /><circle
              cx="12"
              cy="12"
              r="2.6"
            />
          </svg>
          Pré-visualizar
        </a>

        <button
          :if={@post.status != "published"}
          class="btn btn--p"
          type="button"
          phx-click="publish"
        >
          Publicar
        </button>
        <button
          :if={@post.status == "published"}
          class="btn btn--s"
          type="button"
          phx-click="unpublish"
        >
          Despublicar
        </button>
      </div>
    </nav>
    """
  end

  defp palette(assigns) do
    assigns = assign(assigns, :items, Markdown.palette())

    ~H"""
    <aside class="card ed-palette">
      <span class="micro" style="padding:0 10px">Inserir bloco</span>
      <div class="palette">
        <button
          :for={{type, label, key} <- @items}
          type="button"
          class="pitem"
          phx-click="insert"
          phx-value-type={type}
          phx-value-after={@selected}
        >
          <span class="g"><.block_icon type={type} /></span>
          {label}
          <span class="pkey">{key}</span>
        </button>
      </div>
      <p class="small" style="padding:10px 10px 0;border-top:1px solid var(--line)">
        Clique para inserir depois do bloco selecionado, ou digite
        <span class="mono" style="font-size:12px">/</span>
        numa linha vazia.
      </p>
    </aside>
    """
  end

  defp sheet(assigns) do
    ~H"""
    <div class="ed-center">
      <div class="sheet">
        <div style="display:flex;flex-direction:column;gap:14px">
          <span class="micro" style="color:var(--accent)">
            {@post.kind} <span :if={@post.topics != []}>· {Enum.join(@post.topics, " · ")}</span>
          </span>

          <label style="display:block">
            <span class="sr-only">Título do post</span>
            <textarea
              id="ed-title"
              phx-hook="Grow"
              class="t-title"
              rows="1"
              phx-blur="field"
              phx-value-field="title"
              name="value"
              placeholder="O título"
            >{@post.title}</textarea>
          </label>

          <label style="display:block">
            <span class="sr-only">Linha de apoio</span>
            <textarea
              id="ed-dek"
              phx-hook="Grow"
              class="t-dek"
              rows="2"
              phx-blur="field"
              phx-value-field="subtitle"
              name="value"
              placeholder="A linha que diz o que o leitor ganha"
            >{@post.subtitle}</textarea>
          </label>
        </div>

        <hr style="border:0;border-top:1px solid var(--line);margin:26px 0" />

        <div class="ed-blocks">
          <.editable_block
            :for={block <- @blocks}
            block={block}
            selected={@selected}
            slash_for={@slash_for}
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

  defp editable_block(assigns) do
    ~H"""
    <div
      class={"blk t-body #{@selected == @block["_uid"] && "blk--sel"}"}
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

      <.block_body block={@block} />

      <.slash_menu :if={@slash_for == @block["_uid"]} uid={@block["_uid"]} />

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

  defp block_body(%{block: %{"type" => "text"}} = assigns) do
    ~H"""
    <.rich_text
      uid={@block["_uid"]}
      field="paragraphs"
      class="prose"
      value={Enum.join(@block["paragraphs"] || [], "\n\n")}
      placeholder="Escreva, ou digite / para inserir um bloco"
      slash
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
        phx-value-uid={@block["_uid"]}
        phx-value-field="url"
        name="value"
        placeholder="https://…"
        aria-label="Endereço da fonte"
      />
    </aside>
    """
  end

  # A table, a diagram and a key-numbers block carry structure that no prose
  # editor expresses well. They are shown as they will look, and edited as the
  # markdown that produces them — the same text the markdown mode uses, so
  # there is no third representation to learn.
  defp block_body(%{block: %{"type" => type}} = assigns)
       when type in ~w(table diagram keynumbers) do
    assigns = assign(assigns, :source, block_markdown(assigns.block))

    ~H"""
    <div class="ed-structured">
      <div class="ed-structured-render">
        <BlogoWeb.Blocks.block block={Map.delete(@block, "_uid")} />
      </div>
      <textarea
        class="ed-structured-src mono"
        rows={max(length(String.split(@source, "\n")), 3)}
        phx-blur="block_input"
        phx-value-uid={@block["_uid"]}
        phx-value-field="_markdown"
        name="value"
        aria-label="Origem do bloco em markdown"
      >{@source}</textarea>
    </div>
    """
  end

  defp block_body(assigns), do: ~H""

  attr :uid, :string, required: true
  attr :field, :string, required: true
  attr :value, :string, default: ""
  attr :class, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :slash, :boolean, default: false

  # `phx-update="ignore"` is what makes this safe: without it LiveView would
  # replace the node on the next patch and take the caret with it.
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
      data-placeholder={@placeholder}
    >{Phoenix.HTML.raw(BlogoWeb.Blocks.inline(@value))}</div>
    """
  end

  defp slash_menu(assigns) do
    assigns = assign(assigns, :items, Markdown.palette())

    ~H"""
    <div class="slash" phx-click-away="slash_close">
      <div
        :for={{type, label, key} <- @items}
        class="sitem"
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

  attr :label, :string, required: true
  attr :field, :string, required: true
  attr :value, :string, default: nil
  attr :uid, :string, required: true

  defp attachment(assigns) do
    ~H"""
    <div class={"ed-attach #{@value in [nil, ""] && "ed-attach--empty"}"}>
      <span class="ed-attach-plus" aria-hidden="true">+</span>
      <input
        class="ed-inline-input small"
        value={@value}
        phx-blur="block_input"
        phx-value-uid={@uid}
        phx-value-field={@field}
        name="value"
        placeholder={
          if @field == "caption",
            do: "Escreva a legenda — ela deve dizer a conclusão, não o que a figura é",
            else: "Nota de margem"
        }
        aria-label={@label}
      />
    </div>
    """
  end

  defp markdown_pane(assigns) do
    ~H"""
    <div class="mdpane">
      <div class="mdhead">
        <span class="micro" style="padding:0 6px">Markdown</span>
        <span style="flex-grow:1"></span>
        <span :if={@error} class="small" style="color:var(--bad)">{@error}</span>
      </div>
      <div class="mdbody">
        <textarea
          id="md-source"
          phx-hook="Markdown"
          phx-update="ignore"
          class="mdcode"
          spellcheck="false"
          aria-label="Markdown do artigo"
        >{@markdown}</textarea>
      </div>
      <p class="hint">
        <span class="kbd">:::</span>
        abre um bloco do blogo — {Enum.map_join(Checklist.fence_help(), ", ", &elem(&1, 0))}.
      </p>
    </div>
    """
  end

  defp preview_pane(assigns) do
    ~H"""
    <div class="pv">
      <div class="pvhead">
        <span class="micro">Pré-visualização · rola junto</span>
        <span class="small" style={"color:var(--#{if @error, do: "bad", else: "good"})"}>
          {if @error, do: "markdown com erro", else: "markdown válido"}
        </span>
      </div>
      <div class="pvbody">
        <span class="micro" style="color:var(--accent)">{@post.kind}</span>
        <h1 class="pv-h1">{@post.title}</h1>
        <p class="pv-dek">{@post.subtitle}</p>
        <BlogoWeb.Blocks.render_blocks blocks={clean_blocks(@blocks)} />
      </div>
    </div>
    """
  end

  defp side(assigns) do
    ~H"""
    <aside class="ed-side">
      <section class="card" style="padding:20px">
        <h2 class="h3" style="margin-bottom:14px">Publicação</h2>

        <label class="ed-field" style="margin-bottom:12px">
          <span class="micro">Endereço</span>
          <input
            class="input mono"
            value={@post.slug}
            phx-blur="field"
            phx-value-field="slug"
            name="value"
            placeholder="endereco-do-artigo"
          />
        </label>

        <label class="ed-field" style="margin-bottom:12px">
          <span class="micro">Tipo</span>
          <select class="input" phx-change="field" phx-value-field="kind" name="value">
            <option :for={k <- ~w(ensaio nota)} value={k} selected={@post.kind == k}>{k}</option>
          </select>
        </label>

        <div class="ed-field">
          <span class="micro">Marcadores</span>
          <div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center">
            <span :for={topic <- @post.topics} class="tag">
              {topic}
              <button
                type="button"
                phx-click="remove_topic"
                phx-value-topic={topic}
                aria-label={"Remover #{topic}"}
                style="border:0;background:0;cursor:pointer;color:inherit"
              >
                ×
              </button>
            </span>
            <input
              class="ed-topic-add"
              name="topic"
              phx-keydown="add_topic"
              phx-key="Enter"
              placeholder="+ adicionar"
              aria-label="Adicionar marcador"
            />
          </div>
        </div>
      </section>

      <section class="card" style="padding:20px">
        <h2 class="h3" style="margin-bottom:12px">Como aparece na busca</h2>
        <div class="ed-serp">
          <span class="small mono" style="color:var(--ink4)">
            {BlogoWeb.Endpoint.host()} › {@post.slug}
          </span>
          <span class="ed-serp-title">{@search.title}</span>
          <p class="small">{@search.description}</p>
        </div>
        <label class="ed-field" style="margin-top:12px">
          <span class="micro">Descrição para busca</span>
          <textarea
            class="input input--area"
            rows="3"
            phx-blur="field"
            phx-value-field="meta_description"
            name="value"
            placeholder="O resumo que aparece no Google"
          >{@post.meta_description}</textarea>
        </label>
        <p class={"small #{not @search.fits? && "ed-warn"}"} style="margin-top:8px">
          {if @search.fits?,
            do: "Título e resumo dentro do limite",
            else: "Título ou resumo passa do limite e vai ser cortado"}
        </p>
      </section>

      <section class="card" style="padding:20px">
        <h2 class="h3" style="margin-bottom:12px">Antes de publicar</h2>
        <ul class="ed-check">
          <li :for={{status, text} <- @checklist} class={"ed-check--#{status}"}>
            <span class="ed-check-mark" aria-hidden="true">{mark(status)}</span>
            <span>{text}</span>
          </li>
        </ul>
      </section>
    </aside>
    """
  end

  attr :type, :string, required: true

  defp block_icon(assigns) do
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

  # ── small helpers ─────────────────────────────────────────────────────────

  defp block_markdown(block) do
    %{body: %{"blocks" => [Map.delete(block, "_uid")]}}
    |> Markdown.to_markdown()
    |> String.split("---\n\n", parts: 2)
    |> List.last()
    |> String.trim()
  end

  defp estado("published"), do: "publicado"
  defp estado("scheduled"), do: "agendado"
  defp estado(_), do: "rascunho"

  defp variante("note"), do: "nota"
  defp variante("warn"), do: "atenção"
  defp variante("bad"), do: "erro"

  defp mark(:ok), do: "✓"
  defp mark(:warn), do: "!"
  defp mark(:blocked), do: "×"

  defp format_int(n) do
    n
    |> to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1.")
    |> String.reverse()
  end

  defp ha_quanto(nil), do: "agora"

  defp ha_quanto(%DateTime{} = t) do
    case DateTime.diff(DateTime.utc_now(), t, :minute) do
      0 -> "agora"
      1 -> "há 1 minuto"
      n when n < 60 -> "há #{n} minutos"
      n when n < 120 -> "há 1 hora"
      n -> "há #{div(n, 60)} horas"
    end
  end
end
