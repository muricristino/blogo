defmodule BlogoWeb.EditorLive.Index do
  @moduledoc """
  The list a writer lands on. Drafts first, because a draft is the thing that
  still needs something from you.
  """
  use BlogoWeb, :live_view

  alias Blogo.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Posts", editor?: true) |> load()}
  end

  defp load(socket), do: assign(socket, posts: Content.list_posts())

  @impl true
  def handle_event("new", _params, socket) do
    author = List.first(Blogo.Repo.all(Blogo.Content.Author))

    case author do
      nil ->
        {:noreply,
         put_flash(socket, :error, "Crie um autor antes de escrever o primeiro artigo.")}

      author ->
        {:ok, post} = Content.new_draft(author.id)
        {:noreply, push_navigate(socket, to: ~p"/editor/#{post.id}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="lx-admin">
      <nav class="bar ed-bar">
        <a class="brand" href={~p"/"}>
          <span>blogo</span>
        </a>
        <span class="micro">Posts</span>
        <div style="display:flex;align-items:center;gap:8px">
          <.link class="btn btn--s" href={~p"/sair"} method="delete">Sair</.link>
          <button class="btn btn--p" type="button" phx-click="new">Novo post</button>
        </div>
      </nav>

      <main class="ed-shell" style="padding:16px">
        <div class="card ed-list">
          <div :for={post <- @posts} class="ed-list-item">
            <.link navigate={~p"/editor/#{post.id}"} class="ed-list-title">
              {post.title}
            </.link>

            <div class="ed-list-meta">
              <span class={"pill pill--#{post.status}"}>{estado(post.status)}</span>
              <span class="small mono">/{post.slug}</span>
            </div>

            <span class="small mono">{atualizado(post.updated_at)}</span>

            <.link :if={post.status == "published"} class="small" href={~p"/#{post.slug}"}>
              ver no site
            </.link>
            <span :if={post.status != "published"}></span>
          </div>

          <p :if={@posts == []} class="small" style="padding:26px;text-align:center">
            Nenhum post ainda. O botão lá em cima começa o primeiro.
          </p>
        </div>
      </main>
    </div>
    """
  end

  defp estado("published"), do: "publicado"
  defp estado("scheduled"), do: "agendado"
  defp estado(_), do: "rascunho"

  defp atualizado(nil), do: ""

  defp atualizado(%DateTime{} = d) do
    "#{pad(d.day)}/#{pad(d.month)}/#{d.year} #{pad(d.hour)}:#{pad(d.minute)}"
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
end
