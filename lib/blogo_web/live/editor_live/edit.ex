defmodule BlogoWeb.EditorLive.Edit do
  @moduledoc """
  The post editor: two modes over one document.

  Rich mode manipulates the block list; prose blocks are `contenteditable` under
  `phx-update="ignore"`, so LiveView never patches a node the writer has the
  caret in. Markdown mode edits the whole document as text and parses it back —
  a parse error is reported and the last good block list stays, because losing
  an article to a stray colon is unforgivable.
  """
  use BlogoWeb, :live_view

  alias Blogo.Content
  alias Blogo.Content.{Checklist, Markdown, Metrics}
  alias BlogoWeb.EditorLive.{Panel, Sheet, Topbar}

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
       admin?: true,
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
       undo: nil,
       now: DateTime.utc_now(),
       markdown: Markdown.to_markdown(post)
     )
     |> put_blocks(post.body["blocks"] || [])
     |> assign_derived()}
  end

  # `post` is the row as last read; `fields` is what the writer typed. Keeping
  # them separate is load-bearing: writing the change into the struct and then
  # handing that struct to `cast/3` leaves nothing to compare against, so the
  # column is never written and the screen keeps showing a value the database
  # never received. That shipped once, with the save badge turning green.
  @editable ~w(title subtitle slug kind language meta_description)a

  defp fields_of(post) do
    post
    |> Map.take([:topics, :hero | @editable])
    |> Map.new(fn {k, v} -> {k, v} end)
  end

  # "" would fail to cast and silently keep the old value.
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

  # The browser's undo cannot reach this, so the block is kept until the next
  # removal replaces it.
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

  # The last block stays: a sheet with nothing to type in is a dead end.
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

  # The palette advertises /t, /h, /tb; without this they were decoration, and
  # the letters landed in the paragraph as text.
  def handle_event("slash_key", %{"key" => key}, socket) do
    matches = Sheet.slash_matches(socket.assigns.slash_query)

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

        if Sheet.slash_matches(query) == [] do
          {:noreply, assign(socket, slash_for: nil)}
        else
          {:noreply, assign(socket, slash_query: query, slash_at: 0)}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("slash_close", _params, socket), do: {:noreply, assign(socket, slash_for: nil)}

  # Forms with `phx-debounce`, not blur on loose inputs: a writer who typed a
  # caption and reloaded without clicking elsewhere used to lose it while the
  # badge said "salvo".
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

  # The article usually already holds the figure its cover wants; retyping the
  # data would be a second copy to keep in sync.
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

  # Without a tick, "salvo há 1 minuto" stayed on screen for an hour.
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
      # Two tabs on one post were last-write-wins in silence.
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

  # Selecting what was inserted; without it four blocks added in a row came out
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

  defp put_field_value(socket, key, value) do
    socket
    |> assign(fields: Map.put(socket.assigns.fields, key, value))
    |> assign_derived()
  end

  # A broken edit keeps the previous figure rather than blanking the cover.
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

  # Under the selector, not inside it: an option long enough to explain itself
  # is too long to read in a select.

  defp attrs_of(socket) do
    socket.assigns.fields
    |> Map.put(:body, %{"blocks" => clean_blocks(socket.assigns.blocks)})
  end

  defp first_error(:stale) do
    "Este post foi alterado noutro lugar depois que você abriu. Recarregue para ver a versão nova — o que está na tela não foi gravado."
  end

  # The refusal speaks the words the screen uses: the changeset says "hero",
  # which appears nowhere in the interface.
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

  # Session-only id, which `phx-update="ignore"` keys on: stable while the block
  # exists, unique while two do.
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

  # The post as it would be if saved now. Preview, checklist, search snippet and
  # markdown all read this, so none of them can disagree with the others.
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

  # Splitting here means rich mode produces the same block a markdown paste
  # would.
  defp put_field(block, "paragraphs", value) do
    Map.put(block, "paragraphs", String.split(value, ~r/\n{2,}/, trim: true))
  end

  # Parsed with the same reader markdown mode uses; a broken edit keeps the
  # previous block rather than replacing it with nothing.
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
      <Topbar.bar {assigns} />

      <div :if={@undo} class="ed-undo" role="status">
        Bloco removido. <button type="button" phx-click="undo_delete">Desfazer</button>
      </div>

      <div class={"ed-grid ed-grid--#{@mode}"}>
        <%!-- The sheet comes first in the DOM so Tab reaches the title before
              the eleven palette buttons; `order` puts the palette back on the
              left at desktop width. --%>
        <Sheet.sheet :if={@mode == :rich} {assigns} />
        <Topbar.palette :if={@mode == :rich} selected={@selected} />
        <Panel.markdown_pane :if={@mode == :markdown} {assigns} />
        <Panel.preview_pane :if={@mode == :markdown} {assigns} />
        <Panel.side :if={@mode == :rich} {assigns} />
      </div>
    </div>
    """
  end

  # ── small helpers ─────────────────────────────────────────────────────────
end
