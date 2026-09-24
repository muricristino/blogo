defmodule BlogoWeb.EditorLive.Panel do
  @moduledoc """
  The side panel and the markdown pane: what the post is, how it will look in
  search, and what is missing before it can be published.
  """
  use BlogoWeb, :html

  alias Blogo.Content.Checklist

  @doc "The markdown source, beside its preview."
  def markdown_pane(assigns) do
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

  @doc "What the markdown produces, in the article's own components."
  def preview_pane(assigns) do
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

  @doc "Publication, search preview and the checklist."
  def side(assigns) do
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
          <%!-- "pagina" is how a fixed page is written: the author picks it here
                and the page leaves the index, the feed and the topics. --%>
          <select class="input" name="kind">
            <option :for={k <- Blogo.Content.Post.kinds()} value={k} selected={@fields.kind == k}>
              {k}
            </option>
          </select>
        </label>

        <label class="ed-field" style="margin-bottom:12px">
          <span class="micro">Idioma</span>
          <%!-- A língua do artigo, que não é a língua da interface de quem lê:
                o texto continua na língua em que foi escrito, e é esta que vai
                para o `lang` da página e para o `inLanguage`. --%>
          <select class="input" name="language">
            <option
              :for={l <- Blogo.Content.Post.languages()}
              value={l}
              selected={@fields.language == l}
            >
              {l}
            </option>
          </select>
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
        <p class={["small", not @search.fits? && "ed-warn"]} style="margin-top:8px">
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

  defp mark(:ok), do: "✓"
  defp mark(:warn), do: "!"
  defp mark(:blocked), do: "×"

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

  defp form_hint("fluxo"), do: "por onde um caso passa"
  defp form_hint("distribuicao"), do: "o quanto dois grupos se sobrepõem"
  defp form_hint("antes_depois"), do: "o que uma mudança custou"
  defp form_hint("matriz"), do: "onde o erro cai"
  defp form_hint("decisao"), do: "a pergunta e os dois caminhos"
  defp form_hint("linha_tempo"), do: "como aquilo se desenrolou"
  defp form_hint("intervalo"), do: "o que a amostra permite concluir"
  defp form_hint(_), do: nil

  defp hero_json(%{"data" => data}) when is_map(data), do: Jason.encode!(data, pretty: true)
  defp hero_json(_), do: "{}"

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

  defp clean_blocks(blocks), do: Enum.map(blocks, &Map.delete(&1, "_uid"))
end
