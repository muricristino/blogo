defmodule BlogoWeb.Blocks do
  @moduledoc """
  Renders the block list a post carries in `body`.

  Inline markup is a deliberately small dialect — `**bold**`, `*italic*` and
  `` `code` `` — parsed here rather than stored as HTML. Storing HTML would
  mean the database holds markup nobody validates, and a post written today
  would not pick up tomorrow's design system.
  """
  use Phoenix.Component
  import BlogoWeb.Diagrams, only: [diagram: 1]

  attr :blocks, :list, required: true

  def render_blocks(assigns) do
    ~H"""
    <%= for block <- @blocks do %>
      <.block block={block} />
    <% end %>
    """
  end

  attr :block, :map, required: true

  def block(%{block: %{"type" => "text"}} = assigns) do
    ~H"""
    <div class={"prose #{if @block["drop"], do: "prose--drop"}"}>
      <p :for={p <- @block["paragraphs"] || []}><%= inline(p) %></p>
    </div>
    """
  end

  def block(%{block: %{"type" => "section"}} = assigns) do
    ~H"""
    <div class="sechead">
      <span class="secn"><%= @block["n"] %></span>
      <h2 class="sectitle"><%= @block["title"] %></h2>
    </div>
    """
  end

  def block(%{block: %{"type" => "table"}} = assigns) do
    ~H"""
    <figure class="figure">
      <div class="table-wrap">
        <table class="table">
          <thead>
            <tr><th :for={h <- @block["headers"] || []} scope="col"><%= h %></th></tr>
          </thead>
          <tbody>
            <tr :for={row <- @block["rows"] || []}>
              <td :for={{cell, i} <- Enum.with_index(row)}
                  data-label={Enum.at(@block["headers"] || [], i)}><%= inline(cell) %></td>
            </tr>
          </tbody>
        </table>
      </div>
      <figcaption :if={@block["caption"]} class="caption"><%= @block["caption"] %></figcaption>
    </figure>
    """
  end

  def block(%{block: %{"type" => "diagram"}} = assigns) do
    ~H"""
    <figure class="figure">
      <div class="dg-wrap">
        <.diagram form={@block["form"]} data={@block["data"] || %{}} label={@block["alt"] || ""} />
      </div>
      <figcaption :if={@block["caption"]} class="caption"><%= @block["caption"] %></figcaption>
    </figure>
    """
  end

  def block(%{block: %{"type" => "callout"}} = assigns) do
    ~H"""
    <aside class={"callout callout--#{@block["variant"] || "note"}"}>
      <p :if={@block["title"]} class="callout-title"><%= @block["title"] %></p>
      <p class="callout-text"><%= inline(@block["text"]) %></p>
    </aside>
    """
  end

  def block(%{block: %{"type" => "code"}} = assigns) do
    ~H"""
    <figure class="figure">
      <div class="codeblock">
        <span :if={@block["lang"]} class="codeblock-lang"><%= @block["lang"] %></span>
        <pre><code><%= @block["source"] %></code></pre>
      </div>
      <figcaption :if={@block["caption"]} class="caption"><%= @block["caption"] %></figcaption>
    </figure>
    """
  end

  def block(%{block: %{"type" => "quote"}} = assigns) do
    ~H"""
    <blockquote class="quote">
      <p><%= inline(@block["text"]) %></p>
      <cite :if={@block["cite"]}><%= @block["cite"] %></cite>
    </blockquote>
    """
  end

  def block(%{block: %{"type" => "keynumbers"}} = assigns) do
    ~H"""
    <div class="keynums">
      <div :for={item <- @block["items"] || []} class="keynum">
        <span class="keynum-value"><%= item["value"] %></span>
        <span class="keynum-label"><%= item["label"] %></span>
      </div>
    </div>
    """
  end

  def block(%{block: %{"type" => "marginnote"}} = assigns) do
    ~H"""
    <aside class="marginnote"><%= inline(@block["text"]) %></aside>
    """
  end

  def block(%{block: %{"type" => "question"}} = assigns) do
    ~H"""
    <aside class="question">
      <span class="question-label">Pergunta guardada</span>
      <p><%= inline(@block["text"]) %></p>
    </aside>
    """
  end

  def block(%{block: %{"type" => "source"}} = assigns) do
    ~H"""
    <aside class="source">
      <span class="source-label">Origem dos dados</span>
      <p>
        <a :if={@block["url"]} href={@block["url"]} rel="nofollow noopener"><%= @block["title"] %></a>
        <span :if={is_nil(@block["url"])}><%= @block["title"] %></span>
        <span :if={@block["note"]} class="source-note"><%= @block["note"] %></span>
      </p>
    </aside>
    """
  end

  def block(assigns), do: ~H""

  # Escapes first, then re-introduces only the three inline forms, so a post
  # can never inject markup through the database.
  defp inline(nil), do: ""

  defp inline(text) when is_binary(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace(~r/\*\*(.+?)\*\*/s, "<strong>\\1</strong>")
    |> String.replace(~r/(?<!\*)\*([^*]+?)\*(?!\*)/s, "<em>\\1</em>")
    |> String.replace(~r/`(.+?)`/s, "<code>\\1</code>")
    |> Phoenix.HTML.raw()
  end

  defp inline(other), do: to_string(other)
end
