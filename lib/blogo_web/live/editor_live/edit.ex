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
    if connected?(socket), do: Process.send_after(self(), :tick, 30_000)

    {:ok,
     socket
     |> assign(
       post: post,
       fields: fields_of(post),
       page_title: post.title,
       editor?: true,
       mode: :rich,
       selected: nil,
       slash_for: nil,
       slash_query: "",
       slash_at: 0,
       saved_at: post.updated_at,
       dirty?: false,
       timer: nil,
       error: nil,
       hero_error: nil,
       all_series: Content.list_all_series(),
       undo: nil,
       now: DateTime.utc_now(),
       markdown: Markdown.to_markdown(post)
     )
     |> put_blocks(post.body["blocks"] || [])
     |> assign_derived()}
  end

  # `post` is the row as it was last read, and `fields` is what the writer has
  # typed. They have to stay separate: writing a change into the struct and then
  # handing that same struct to `Ecto.Changeset.cast/3` leaves nothing for cast
  # to compare against, so the column is never written and the screen goes on
  # showing a value the database never received. That bug shipped in the first
  # version of this file and nothing on screen contradicted it — the save badge
  # still turned green.
  @editable ~w(title subtitle slug kind meta_description series_id series_position)a

  defp fields_of(post) do
    post
    |> Map.take([:topics, :hero | @editable])
    |> Map.new(fn {k, v} -> {k, v} end)
  end

  # A select sends "" for "nenhuma" and a number input sends a string. Both
  # have to reach the changeset as nil rather than as "", which would fail to
  # cast and silently keep the old value.
  defp normalise(:series_id, ""), do: nil
  defp normalise(:series_position, ""), do: nil
  defp normalise(_key, value), do: value

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
    insert_block(socket, type, params["after"])
  end

  def handle_event("move", %{"uid" => uid, "dir" => dir}, socket) do
    {:noreply, socket |> put_blocks(move(socket.assigns.blocks, uid, dir)) |> touched()}
  end

  # Removing is one click and the browser's undo cannot reach it, so the block
  # is kept with its position until something else is removed.
  def handle_event("delete", %{"uid" => uid}, socket) do
    blocks = socket.assigns.blocks
    index = Enum.find_index(blocks, &(&1["_uid"] == uid))
    removed = index && Enum.at(blocks, index)

    {:noreply,
     socket
     |> put_blocks(List.delete_at(blocks, index || -1))
     |> assign(selected: nil, undo: removed && {index, removed})
     |> touched()}
  end

  # Backspace in an empty block removes it and puts the caret at the end of the
  # one above, which is what every editor does. The last block stays: a sheet
  # with nothing to type in is a dead end.
  def handle_event("delete_empty", %{"uid" => uid}, socket) do
    blocks = socket.assigns.blocks

    if length(blocks) <= 1 do
      {:noreply, socket}
    else
      index = Enum.find_index(blocks, &(&1["_uid"] == uid))
      previous = index && index > 0 && Enum.at(blocks, index - 1)

      socket =
        socket
        |> put_blocks(List.delete_at(blocks, index || -1))
        |> touched()

      case previous do
        %{"_uid" => prev_uid} ->
          {:noreply,
           socket
           |> assign(selected: prev_uid)
           |> push_event("focus_block", %{uid: prev_uid})}

        _ ->
          {:noreply, socket}
      end
    end
  end

  def handle_event("undo_delete", _params, socket) do
    case socket.assigns.undo do
      {index, block} ->
        blocks = List.insert_at(socket.assigns.blocks, index, block)

        {:noreply,
         socket
         |> put_blocks(blocks)
         |> assign(undo: nil, selected: block["_uid"])
         |> touched()}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("slash", %{"uid" => uid}, socket) do
    {:noreply, assign(socket, slash_for: uid, selected: uid, slash_query: "", slash_at: 0)}
  end

  # The palette advertises /t, /h, /tb. Before this they were decoration: the
  # menu opened and then ignored every key, so the letters landed in the
  # paragraph as text and Enter inserted a line break.
  def handle_event("slash_key", %{"key" => key}, socket) do
    matches = slash_matches(socket.assigns.slash_query)

    case key do
      "ArrowDown" ->
        {:noreply,
         assign(socket, slash_at: min(socket.assigns.slash_at + 1, length(matches) - 1))}

      "ArrowUp" ->
        {:noreply, assign(socket, slash_at: max(socket.assigns.slash_at - 1, 0))}

      "Enter" ->
        case Enum.at(matches, socket.assigns.slash_at) do
          {type, _label, _key} -> insert_block(socket, type, socket.assigns.slash_for)
          nil -> {:noreply, assign(socket, slash_for: nil)}
        end

      "Escape" ->
        {:noreply, assign(socket, slash_for: nil)}

      "Backspace" ->
        query = String.slice(socket.assigns.slash_query, 0..-2//1)

        if query == "" and socket.assigns.slash_query == "" do
          {:noreply, assign(socket, slash_for: nil)}
        else
          {:noreply, assign(socket, slash_query: query, slash_at: 0)}
        end

      <<letter::utf8>> ->
        query = socket.assigns.slash_query <> <<letter::utf8>>

        if slash_matches(query) == [] do
          {:noreply, assign(socket, slash_for: nil)}
        else
          {:noreply, assign(socket, slash_query: query, slash_at: 0)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("slash_close", _params, socket), do: {:noreply, assign(socket, slash_for: nil)}

  # An input outside a form sends `%{"value" => ...}`, so the field it belongs
  # to travels as a phx-value and is matched against a fixed list — never
  # `String.to_atom` on something that arrived from a browser.
  # The panel and the sheet heading are forms, so a change event carries the
  # fields by name and `phx-debounce` saves while the writer types. The previous
  # version listened for blur on loose inputs: a writer who typed a caption and
  # reloaded without clicking elsewhere lost it, while the badge said "salvo".
  def handle_event("head", params, socket) do
    socket =
      Enum.reduce(@editable, socket, fn key, acc ->
        case Map.fetch(params, to_string(key)) do
          {:ok, value} -> put_field_value(acc, key, normalise(key, value))
          :error -> acc
        end
      end)

    {:noreply, touched(socket)}
  end

  def handle_event("hero", params, socket) do
    case build_hero(socket.assigns.fields.hero, params) do
      {:ok, hero} ->
        {:noreply,
         socket
         |> assign(hero_error: nil)
         |> put_field_value(:hero, hero)
         |> touched()}

      {:error, message} ->
        {:noreply, assign(socket, hero_error: message)}
    end
  end

  # The commonest case by far: the article already contains the figure that
  # should be on its cover, and retyping its data would be a second copy to
  # keep in sync.
  def handle_event("hero_from_block", _params, socket) do
    case Enum.find(socket.assigns.blocks, &(&1["type"] == "diagram")) do
      nil ->
        {:noreply,
         put_flash(socket, :error, "O artigo ainda não tem nenhum diagrama para usar como capa.")}

      block ->
        hero = block |> Map.drop(["_uid", "type", "note"]) |> Map.put("form", block["form"])
        {:noreply, socket |> put_field_value(:hero, hero) |> touched()}
    end
  end

  def handle_event("add_topic", %{"value" => topic}, socket) do
    topic = String.trim(topic)
    topics = socket.assigns.fields.topics

    if topic == "" or topic in topics do
      {:noreply, socket}
    else
      {:noreply, socket |> put_field_value(:topics, topics ++ [topic]) |> touched()}
    end
  end

  def handle_event("remove_topic", %{"topic" => topic}, socket) do
    topics = List.delete(socket.assigns.fields.topics, topic)
    {:noreply, socket |> put_field_value(:topics, topics) |> touched()}
  end

  def handle_event("mode", %{"to" => "markdown"}, socket) do
    markdown = Markdown.to_markdown(working_post(socket))

    {:noreply, assign(socket, mode: :markdown, markdown: markdown, error: nil)}
  end

  def handle_event("mode", %{"to" => "rich"}, socket) do
    {:noreply, assign(socket, mode: :rich, slash_for: nil)}
  end

  def handle_event("markdown_input", %{"value" => text}, socket) do
    socket = assign(socket, markdown: text)

    case Markdown.from_markdown(text) do
      {:ok, attrs} ->
        fields = Map.merge(socket.assigns.fields, Map.delete(attrs, :body))

        {:noreply,
         socket
         |> assign(fields: fields, error: nil)
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

  # "salvo há 1 minuto" stayed on screen for an hour. The badge re-renders on a
  # tick rather than only when something else happens to change.
  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, 30_000)
    {:noreply, assign(socket, now: DateTime.utc_now())}
  end

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
      # Two tabs on one post used to be last-write-wins in silence. The write
      # is refused and the writer decides which version survives.
      {:error, :stale} ->
        put_flash(
          socket,
          :error,
          "Este post foi alterado noutro lugar depois que você abriu. Recarregue para ver a versão nova — o que está na tela não foi gravado."
        )

      {:ok, post} ->
        socket
        |> assign(post: post, saved_at: post.updated_at, dirty?: false, timer: nil)
        |> assign_derived()

      {:error, changeset} ->
        put_flash(socket, :error, first_error(changeset))
    end
  end

  # Inserting selects what was inserted. Without this the palette kept
  # inserting after the same old block, so four blocks added in a row came out
  # in reverse order.
  defp insert_block(socket, type, after_uid) do
    block = new_block(type)
    blocks = insert_after(socket.assigns.blocks, after_uid, block)

    {:noreply,
     socket
     |> put_blocks(blocks)
     |> assign(slash_for: nil, selected: block["_uid"])
     |> push_event("focus_block", %{uid: block["_uid"]})
     |> touched()}
  end

  defp slash_matches(""), do: Markdown.palette()

  defp slash_matches(query) do
    q = String.downcase(query)

    Enum.filter(Markdown.palette(), fn {_type, label, key} ->
      String.starts_with?(String.trim_leading(key, "/"), q) or
        String.contains?(String.downcase(label), q)
    end)
  end

  defp put_field_value(socket, key, value) do
    socket
    |> assign(fields: Map.put(socket.assigns.fields, key, value))
    |> assign_derived()
  end

  # Choosing a form starts a hero with an empty dataset; clearing the form
  # removes it. The data is JSON because a diagram carries numbers no prose
  # expresses, and a broken edit keeps the previous figure rather than blanking
  # the cover.
  defp build_hero(_current, %{"form" => ""}), do: {:ok, nil}

  defp build_hero(current, %{"form" => form} = params) do
    current = current || %{}

    hero =
      current
      |> Map.put("form", form)
      |> put_present("alt", params["alt"])
      |> put_present("caption", params["caption"])

    case params["data"] do
      nil ->
        {:ok, Map.put_new(hero, "data", %{})}

      json ->
        case Jason.decode(String.trim(json)) do
          {:ok, data} when is_map(data) -> {:ok, Map.put(hero, "data", data)}
          _ -> {:error, "Os dados não são JSON válido — a figura anterior foi mantida."}
        end
    end
  end

  defp build_hero(_current, _params), do: {:ok, nil}

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, ""), do: Map.delete(map, key)
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp hero_json(%{"data" => data}) when is_map(data), do: Jason.encode!(data, pretty: true)
  defp hero_json(_), do: "{}"

  defp forms do
    [
      {"fluxo", "fluxo"},
      {"distribuicao", "distribuição"},
      {"antes_depois", "antes e depois"},
      {"matriz", "matriz"},
      {"decisao", "decisão"},
      {"linha_tempo", "linha do tempo"},
      {"intervalo", "intervalo"}
    ]
  end

  # What each form is for, under the selector rather than inside it: an option
  # long enough to explain itself is an option too long to read in a select.
  defp form_hint("fluxo"), do: "por onde um caso passa"
  defp form_hint("distribuicao"), do: "o quanto dois grupos se sobrepõem"
  defp form_hint("antes_depois"), do: "o que uma mudança custou"
  defp form_hint("matriz"), do: "onde o erro cai"
  defp form_hint("decisao"), do: "a pergunta e os dois caminhos"
  defp form_hint("linha_tempo"), do: "como aquilo se desenrolou"
  defp form_hint("intervalo"), do: "o que a amostra permite concluir"
  defp form_hint(_), do: nil

  # The shape each form expects, so nobody has to guess the schema from an
  # empty box. This is the only place the editor explains a data format, and it
  # exists because the alternative is trial and error.
  defp hero_hint("fluxo"), do: ~S|{"steps": [{"label": "passo", "accent": true}]}|

  defp hero_hint("distribuicao"),
    do:
      ~S|{"rows": [{"title": "…", "auc": "0,95", "pos_c": 285, "pos_s": 28, "neg_c": 85, "neg_s": 26}]}|

  defp hero_hint("antes_depois"),
    do:
      ~S|{"from_label": "antes", "to_label": "depois", "max": 100, "rows": [{"label": "…", "from": 89, "to": 51}]}|

  defp hero_hint("matriz"),
    do:
      ~S|{"col_a": "…", "col_b": "…", "row_a": "…", "row_b": "…", "cells": [{"value": "68", "label": "acerto", "accent": true}]}|

  defp hero_hint("decisao"), do: ~S|{"question": "…?", "no": "…", "yes": "…"}|

  defp hero_hint("linha_tempo"),
    do: ~S|{"events": [{"time": "dia 0", "label": "…", "note": "…"}]}|

  defp hero_hint("intervalo"),
    do:
      ~S|{"ticks": ["0,4", "1,0"], "rows": [{"label": "…", "lo": 0.42, "hi": 0.98, "point": 0.72}]}|

  defp hero_hint(_), do: ""

  defp attrs_of(socket) do
    socket.assigns.fields
    |> Map.put(:body, %{"blocks" => clean_blocks(socket.assigns.blocks)})
  end

  defp first_error(:stale) do
    "Este post foi alterado noutro lugar depois que você abriu. Recarregue para ver a versão nova — o que está na tela não foi gravado."
  end

  # The refusal speaks the words the screen uses. The changeset says "hero",
  # which appears nowhere in the interface — a writer who read it had no way to
  # connect it to the "Diagrama de capa" panel two centimetres to the right.
  defp first_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, [msg | _]} -> "#{rotulo(field)} #{msg}" end)
    |> List.first()
    |> Kernel.||("não foi possível salvar")
  end

  defp rotulo(:hero), do: "O diagrama de capa"
  defp rotulo(:title), do: "O título"
  defp rotulo(:slug), do: "O endereço"
  defp rotulo(field), do: to_string(field)

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

  # The post as it would be if saved right now: the row, with what the writer
  # has typed on top. Everything that reads the document — the preview, the
  # checklist, the search snippet, the markdown — reads this, so none of them
  # can disagree with the others.
  defp working_post(socket) do
    socket.assigns.post
    |> Map.merge(socket.assigns.fields)
    |> Map.put(:body, %{"blocks" => clean_blocks(socket.assigns.blocks)})
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
    post = working_post(socket)
    blocks = post.body["blocks"]

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

      <div :if={@undo} class="ed-undo" role="status">
        Bloco removido. <button type="button" phx-click="undo_delete">Desfazer</button>
      </div>

      <div class={"ed-grid ed-grid--#{@mode}"}>
        <%!-- The sheet comes first in the DOM so Tab reaches the title before
              the eleven palette buttons; `order` puts the palette back on the
              left at desktop width. --%>
        <.sheet :if={@mode == :rich} {assigns} />
        <.palette :if={@mode == :rich} selected={@selected} />
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
          <span class="ed-title">{@fields.title}</span>
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
        {if @dirty?, do: "salvando…", else: "salvo #{ha_quanto(@saved_at, @now)}"}
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

  attr :uid, :string, required: true
  attr :field, :string, required: true
  attr :value, :string, default: nil
  attr :paragraphs, :list, default: nil
  attr :class, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :slash, :boolean, default: false
  attr :slash_open, :boolean, default: false

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
        class={"sitem #{i == @at && "is-on"}"}
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

  # A caption is a sentence, not a value: an input of one line hid the end of
  # every caption of normal length and showed the inline markup raw.
  defp attachment(assigns) do
    ~H"""
    <div class={"ed-attach #{@value in [nil, ""] && "ed-attach--empty"}"}>
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
        <span class="micro" style="color:var(--accent)">{@fields.kind}</span>
        <h1 class="pv-h1">{@fields.title}</h1>
        <p class="pv-dek">{BlogoWeb.Blocks.inline(@fields.subtitle)}</p>
        <BlogoWeb.Blocks.render_blocks blocks={clean_blocks(@blocks)} />
      </div>
    </div>
    """
  end

  defp side(assigns) do
    ~H"""
    <aside class="ed-side">
      <form id="ed-publish" class="card" style="padding:20px" phx-change="head">
        <h2 class="h3" style="margin-bottom:14px">Publicação</h2>

        <label class="ed-field" style="margin-bottom:12px">
          <span class="micro">Endereço</span>
          <input
            class="input mono"
            value={@fields.slug}
            name="slug"
            phx-debounce="400"
            placeholder="endereco-do-artigo"
          />
        </label>

        <label class="ed-field" style="margin-bottom:12px">
          <span class="micro">Tipo</span>
          <select class="input" name="kind">
            <option :for={k <- ~w(ensaio nota)} value={k} selected={@fields.kind == k}>{k}</option>
          </select>
        </label>

        <label class="ed-field" style="margin-bottom:12px">
          <span class="micro">Série</span>
          <select class="input" name="series_id">
            <option value="">nenhuma</option>
            <option
              :for={s <- @all_series}
              value={s.id}
              selected={to_string(@fields.series_id) == to_string(s.id)}
            >
              {s.name}
            </option>
          </select>
        </label>

        <label :if={@fields.series_id} class="ed-field" style="margin-bottom:12px">
          <span class="micro">Posição na série</span>
          <input
            class="input mono"
            type="number"
            min="1"
            name="series_position"
            value={@fields.series_position}
            phx-debounce="400"
          />
        </label>

        <div class="ed-field">
          <span class="micro">Marcadores</span>
          <div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center">
            <span :for={topic <- @fields.topics} class="tag">
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
      </form>

      <section class="card" style="padding:20px">
        <h2 class="h3">Diagrama de capa</h2>
        <p class="small">
          A figura do card e da lista. Um artigo não publica sem ela.
        </p>

        <div :if={@fields.hero} class="ed-hero-preview">
          <BlogoWeb.Diagrams.diagram
            form={@fields.hero["form"]}
            data={@fields.hero["data"] || %{}}
            label={@fields.hero["alt"] || ""}
          />
        </div>

        <form id="ed-hero" phx-change="hero" style="display:flex;flex-direction:column;gap:10px">
          <label class="ed-field">
            <span class="micro">Forma</span>
            <select class="input" name="form">
              <option value="">nenhuma</option>
              <option
                :for={{value, label} <- forms()}
                value={value}
                selected={@fields.hero && @fields.hero["form"] == value}
              >
                {label}
              </option>
            </select>
            <span :if={@fields.hero} class="small">{form_hint(@fields.hero["form"])}</span>
          </label>

          <label :if={@fields.hero} class="ed-field">
            <span class="micro">Descrição para leitor de tela</span>
            <textarea
              class="input input--area"
              rows="2"
              name="alt"
              phx-debounce="400"
              placeholder="O que a figura mostra, em uma frase"
            >{@fields.hero["alt"]}</textarea>
          </label>

          <label :if={@fields.hero} class="ed-field">
            <span class="micro">Legenda</span>
            <input
              class="input"
              name="caption"
              value={@fields.hero["caption"]}
              phx-debounce="400"
              placeholder="A conclusão que a figura carrega"
            />
          </label>

          <label :if={@fields.hero} class="ed-field">
            <span class="micro">Dados</span>
            <textarea
              class="input input--area mono"
              style="min-height:110px;font-size:12px"
              rows="5"
              name="data"
              phx-debounce="600"
            >{hero_json(@fields.hero)}</textarea>
          </label>

          <p :if={@hero_error} class="small ed-warn">{@hero_error}</p>
          <p :if={@fields.hero && is_nil(@hero_error)} class="small">
            {hero_hint(@fields.hero["form"])}
          </p>
        </form>

        <button
          :if={@fields.hero == nil}
          type="button"
          class="btn btn--s"
          phx-click="hero_from_block"
        >
          Usar um diagrama do artigo
        </button>
      </section>

      <form id="ed-seo" class="card" style="padding:20px" phx-change="head">
        <h2 class="h3" style="margin-bottom:12px">Como aparece na busca</h2>
        <div class="ed-serp">
          <span class="small mono" style="color:var(--ink4)">
            {BlogoWeb.Endpoint.host()} › {@fields.slug}
          </span>
          <span class="ed-serp-title">{@search.title}</span>
          <p class="small">{@search.description}</p>
        </div>
        <label class="ed-field" style="margin-top:12px">
          <span class="micro">Descrição para busca</span>
          <textarea
            class="input input--area"
            rows="3"
            name="meta_description"
            phx-debounce="400"
            placeholder="O resumo que aparece no Google"
          >{@fields.meta_description}</textarea>
        </label>
        <p class={"small #{not @search.fits? && "ed-warn"}"} style="margin-top:8px">
          {if @search.fits?,
            do: "Título e resumo dentro do limite",
            else: "Título ou resumo passa do limite e vai ser cortado"}
        </p>
      </form>

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

  defp ha_quanto(nil, _now), do: "agora"

  defp ha_quanto(%DateTime{} = t, now) do
    case DateTime.diff(now, t, :minute) do
      0 -> "agora"
      1 -> "há 1 minuto"
      n when n < 60 -> "há #{n} minutos"
      n when n < 120 -> "há 1 hora"
      n -> "há #{div(n, 60)} horas"
    end
  end
end
