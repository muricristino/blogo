defmodule BlogoWeb.EditorLive.Topbar do
  @moduledoc """
  The editor's bar: where the post stands, whether it is saved, and the two
  buttons that change that.
  """
  use BlogoWeb, :html

  alias Blogo.Content.Markdown
  alias BlogoWeb.EditorLive.Sheet

  @doc "Where the post stands, and the buttons that change that."
  def bar(assigns) do
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

  @doc "The eleven blocks, with the shortcut each one answers to."
  def palette(assigns) do
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
          <span class="g"><Sheet.block_icon type={type} /></span>
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

  defp estado("published"), do: "publicado"
  defp estado("scheduled"), do: "agendado"
  defp estado(_), do: "rascunho"

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
