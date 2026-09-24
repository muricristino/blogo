defmodule BlogoWeb.PanelLive.Index do
  @moduledoc """
  The panel: what is being read, where it came from, how far people get, and
  what is waiting on the author.

  Every figure here is counted, and the screen distinguishes three states that
  a naive panel collapses into one zero:

    * **not measured** — collection has not started, or the figure has no
      source at all (subscribers, because no newsletter exists);
    * **measured, nothing happened** — real zero, worth seeing;
    * **measured** — a number.

  Collapsing the first into the second is how a panel ends up telling its owner
  that nobody read the article they just published.
  """
  use BlogoWeb, :live_view

  alias Blogo.Analytics
  alias Blogo.Content
  alias Blogo.Content.Author

  @periods [{7, "7 dias"}, {30, "30 dias"}, {90, "90 dias"}, {:all, "Tudo"}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Painel",
       # The admin stylesheet is keyed on this flag; the panel is the same
       # surface as the editor and shares `.bar`, `.card` and `.btn`.
       admin?: true,
       period: 30,
       filter: "todos",
       autor_aberto?: false,
       site_aberto?: false,
       confirmando: nil
     )
     |> allow_upload(:foto,
       accept: ~w(.png .jpg .jpeg .webp),
       max_entries: 1,
       max_file_size: Author.max_photo_bytes(),
       # A photo is chosen, not typed, so there is no moment afterwards when
       # someone would press Salvar. It is stored as soon as it arrives, which
       # is the same promise every other field on this screen makes.
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> load_author()
     |> load_site()
     |> load()}
  end

  @impl true
  # O parâmetro não pode se chamar `value`: um <button> tem uma propriedade
  # `value` nativa (vazia), e ela vence o `phx-value-value` na hora de montar
  # os params. O painel inteiro ficou com os dois seletores mortos no navegador
  # por causa disso, e os testes não viram porque disparam o evento direto.
  def handle_event("period", %{"periodo" => value}, socket) do
    {:noreply, socket |> assign(period: parse_period(value)) |> load()}
  end

  def handle_event("filter", %{"filtro" => value}, socket) do
    {:noreply, assign(socket, filter: value)}
  end

  def handle_event("site_abrir", _params, socket) do
    {:noreply, assign(socket, site_aberto?: not socket.assigns.site_aberto?)}
  end

  def handle_event("site_validar", %{"site" => attrs}, socket) do
    changeset =
      socket.assigns.site
      |> Content.change_site(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, site_form: to_form(changeset))}
  end

  def handle_event("site_salvar", %{"site" => attrs}, socket) do
    case Content.update_site(attrs) do
      {:ok, _site} ->
        {:noreply,
         socket
         |> load_site()
         |> assign(site_aberto?: false)
         |> put_flash(
           :info,
           "Nome do site atualizado. Ele muda no cabeçalho, no rodapé e no título das páginas."
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, site_form: to_form(changeset))}
    end
  end

  # This one saves on the click instead of waiting for the form's "Salvar".
  # A switch that looks flipped and was never written is the same silent loss
  # as a save badge that lies, and it sits outside the form so that flipping it
  # cannot throw away a name someone is in the middle of typing.
  def handle_event("destaque_figura", %{"ligado" => ligado}, socket) do
    case Content.update_site(%{"featured_hero" => ligado}) do
      {:ok, site} ->
        {:noreply,
         socket
         |> assign(site: site)
         |> put_flash(:info, aviso_destaque(site.featured_hero))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível guardar essa escolha.")}
    end
  end

  def handle_event("autor_abrir", _params, socket) do
    {:noreply, assign(socket, autor_aberto?: not socket.assigns.autor_aberto?)}
  end

  def handle_event("autor_validar", %{"author" => attrs}, socket) do
    changeset =
      socket.assigns.author
      |> Content.change_author(with_same_as(attrs))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, author_form: to_form(changeset))}
  end

  def handle_event("autor_salvar", %{"author" => attrs}, socket) do
    case Content.update_author(socket.assigns.author, with_same_as(attrs)) do
      {:ok, author} ->
        {:noreply,
         socket
         |> assign(author: author, author_form: to_form(Content.change_author(author)))
         |> put_flash(
           :info,
           "Perfil atualizado. O nome muda no site, no artigo e nos dados estruturados."
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, author_form: to_form(changeset))}
    end
  end

  # The form exists so the file input has one; `auto_upload` means the bytes
  # are on their way before this fires, and `handle_progress/3` stores them.
  def handle_event("foto_escolhida", _params, socket), do: {:noreply, socket}

  def handle_event("foto_descartar", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :foto, ref)}
  end

  def handle_event("foto_remover", _params, socket) do
    case Content.delete_author_photo(socket.assigns.author) do
      {:ok, _author} ->
        {:noreply,
         socket
         |> load_author()
         |> put_flash(:info, "Foto removida. Volta a aparecer o monograma com as suas iniciais.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover a foto.")}
    end
  end

  def handle_event("publicar", %{"id" => id}, socket) do
    post = Content.get_post!(id)

    case Content.publish_post(post) do
      {:ok, post} ->
        {:noreply,
         socket
         |> load()
         |> put_flash(:info, "Publicado em /#{post.slug}")}

      {:error, :stale} ->
        {:noreply, put_flash(socket, :error, "Este post foi alterado noutro lugar. Recarregue.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, primeiro_erro(changeset))}
    end
  end

  def handle_event("confirmar_remocao", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirmando: String.to_integer(id))}
  end

  def handle_event("cancelar_remocao", _params, socket) do
    {:noreply, assign(socket, confirmando: nil)}
  end

  def handle_event("remover", %{"id" => id}, socket) do
    post = Content.get_post!(id)

    case Content.delete_draft(post) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(confirmando: nil)
         |> load()
         |> put_flash(:info, "Rascunho “#{post.title}” removido.")}

      {:error, :published} ->
        {:noreply,
         socket
         |> assign(confirmando: nil)
         |> put_flash(:error, "Um artigo publicado não é removido daqui: despublique primeiro.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover.")}
    end
  end

  # The uploaded file lands in a temporary directory that belongs to the
  # request, so the bytes are read and handed to the database here and now:
  # nothing about this container's filesystem outlives the next deploy.
  defp handle_progress(:foto, entry, socket) do
    if entry.done? do
      bytes =
        consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, File.read!(path)} end)

      case Content.put_author_photo(socket.assigns.author, bytes) do
        {:ok, _author} ->
          {:noreply,
           socket
           |> load_author()
           |> put_flash(
             :info,
             "Foto salva. Aparece no fim de cada artigo e na página sobre você."
           )}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, primeiro_erro(changeset))}
      end
    else
      {:noreply, socket}
    end
  end

  # O formulário manda os perfis como um texto por linha, que é como se edita
  # uma lista curta sem inventar uma interface de lista.
  defp with_same_as(%{"same_as_text" => text} = attrs) do
    attrs
    |> Map.delete("same_as_text")
    |> Map.put("same_as", String.split(text, ~r/[\n,]/))
  end

  defp with_same_as(attrs), do: attrs

  defp primeiro_erro(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, [msg | _]} -> "#{rotulo(field)} #{msg}" end)
    |> List.first()
    |> Kernel.||("não foi possível publicar")
  end

  defp rotulo(:photo), do: "A foto"
  defp rotulo(:hero), do: "O diagrama de capa"
  defp rotulo(:title), do: "O título"
  defp rotulo(:slug), do: "O endereço"
  defp rotulo(field), do: to_string(field)

  defp aviso_destaque(true),
    do: "O card em destaque volta a desenhar o diagrama do artigo."

  defp aviso_destaque(false),
    do:
      "O card em destaque fica só com o texto. O diagrama continua no artigo e na imagem " <>
        "que aparece quando alguém compartilha o link."

  defp load_site(socket) do
    site = Content.the_site()

    assign(socket,
      site: site,
      site_name: Content.site_name(site),
      site_unnamed?: Blogo.Content.Site.unnamed?(site),
      site_form: to_form(Content.change_site(site))
    )
  end

  defp load_author(socket) do
    case Content.the_author() do
      nil ->
        assign(socket, author: nil, author_form: nil)

      author ->
        assign(socket, author: author, author_form: to_form(Content.change_author(author)))
    end
  end

  defp parse_period("all"), do: :all

  defp parse_period(value) do
    case Integer.parse(value) do
      {n, _} when n in [7, 30, 90] -> n
      _ -> 30
    end
  end

  defp load(socket) do
    period = socket.assigns.period
    range = Analytics.window(period)

    posts = Content.list_posts()
    per_post = Analytics.by_post(range)
    curve = Analytics.depth_curve(range)

    assign(socket,
      posts: posts,
      per_post: per_post,
      totals: Analytics.totals(range),
      previous: previous_totals(period),
      daily: Analytics.daily(range),
      sources: Analytics.sources(range),
      curve: curve,
      drop: Analytics.steepest_drop(curve),
      queue: Analytics.queue(),
      measuring?: Analytics.measuring?(),
      since: Analytics.collecting_since(),
      counts: counts(posts)
    )
  end

  defp previous_totals(period) do
    case Analytics.previous_window(period) do
      nil -> nil
      range -> Analytics.totals(range)
    end
  end

  defp counts(posts) do
    Enum.frequencies_by(posts, & &1.status)
  end

  # ── render ────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="lx-admin">
      <.topbar site_name={@site_name} />

      <main class="pn-shell">
        <header class="pn-head">
          <div>
            <h1 class="h1">Painel</h1>
            <p class="small">{resumo(@counts)}</p>
          </div>

          <span class="seg">
            <button
              :for={{value, label} <- periods()}
              type="button"
              class={@period == value && "is-on"}
              phx-click="period"
              phx-value-periodo={to_string(value)}
            >
              {label}
            </button>
          </span>
        </header>

        <p :if={not @measuring?} class="pn-empty">
          <strong>Ainda não há leituras registradas.</strong>
          A medição começa sozinha na primeira visita a um artigo publicado — só conta quem abre
          a página num navegador, então robô de busca não entra na conta.
        </p>

        <p :if={@measuring? and @since} class="small pn-since">
          Medindo desde {data_curta(@since)}.
          <span :if={@period != :all and janela_maior_que_coleta?(@since, @period)}>
            A janela escolhida é maior que isso, então os dias anteriores estão vazios por não
            terem sido medidos — não por ninguém ter lido.
          </span>
        </p>

        <.kpis totals={@totals} previous={@previous} daily={@daily} />

        <section class="pn-two">
          <figure class="card pn-chart">
            <div class="pn-chart-head">
              <span>
                <span class="h3">Leituras por dia</span>
                <span class="small">{periodo_label(@period)} · todas as publicações</span>
              </span>
              <span class="small mono">total {numero(@totals.reads)}</span>
            </div>

            <BlogoWeb.Charts.bars
              :if={@totals.reads > 0}
              series={@daily}
              label={"Leituras por dia. Total de #{@totals.reads} no período."}
            />
            <p :if={@totals.reads == 0} class="small pn-nothing">
              Nenhuma leitura neste período.
            </p>
          </figure>

          <div class="pn-side">
            <figure class="card pn-chart">
              <span>
                <span class="h3">De onde vêm</span>
                <span class="small">
                  {if @sources == [],
                    do: "Sem leituras no período",
                    else: "Origem das #{numero(@totals.reads)} leituras"}
                </span>
              </span>

              <BlogoWeb.Charts.hbars
                :if={@sources != []}
                rows={@sources}
                label={"Origem do tráfego: " <> Enum.map_join(@sources, ", ", &"#{&1.source} #{&1.pct} por cento")}
              />
            </figure>

            <figure class="card pn-chart">
              <span>
                <span class="h3">Até onde leem</span>
                <span class="small">Leitores ainda na página, por trecho do artigo</span>
              </span>

              <BlogoWeb.Charts.depth
                :if={@curve != []}
                curve={@curve}
                label={"Curva de conclusão: #{List.last(@curve).pct} por cento chegam ao fim do artigo."}
              />

              <p :if={@curve == []} class="small pn-nothing">
                Sem leituras no período.
              </p>
              <p :if={@drop} class="small">
                A queda mais forte é entre {@drop.from}% e {@drop.to}% do artigo, onde {@drop.drop} de cada 100 leitores param.
              </p>
            </figure>
          </div>
        </section>

        <.site_card
          site={@site}
          name={@site_name}
          unnamed?={@site_unnamed?}
          form={@site_form}
          aberto?={@site_aberto?}
        />

        <.author_card
          :if={@author}
          author={@author}
          form={@author_form}
          upload={@uploads.foto}
          aberto?={@autor_aberto?}
        />

        <section class="pn-two">
          <div class="pn-posts">
            <div class="pn-posts-head">
              <span class="h3" style="font-size:17px">Publicações</span>
              <span class="seg">
                <button
                  :for={
                    {value, label} <- [
                      {"todos", "Todos"},
                      {"published", "Publicados"},
                      {"draft", "Rascunhos"}
                    ]
                  }
                  type="button"
                  class={@filter == value && "is-on"}
                  phx-click="filter"
                  phx-value-filtro={value}
                >
                  {label}
                </button>
              </span>
            </div>

            <.post_table
              posts={filtrar(@posts, @filter)}
              per_post={@per_post}
              measuring?={@measuring?}
              confirmando={@confirmando}
            />
          </div>

          <div class="card pn-queue">
            <span class="h3">Precisa de você</span>

            <div :if={@queue == []} class="small">
              Nada pendente.
            </div>

            <div :for={item <- @queue} class="todo">
              <span class={"pn-todo-mark pn-todo-mark--#{item.kind}"} aria-hidden="true">
                <.queue_icon kind={item.kind} />
              </span>
              <span>
                <span class="pn-todo-text">{item.text}</span>
                <.link :if={item.href} class="small" navigate={item.href}>{item.action}</.link>
              </span>
            </div>

            <p class="small pn-queue-foot">
              Comentários e newsletter ainda não existem, então nada sobre eles aparece aqui.
            </p>
          </div>
        </section>
      </main>
    </div>
    """
  end

  attr :site_name, :string, required: true

  defp topbar(assigns) do
    ~H"""
    <nav class="bar ed-bar">
      <div style="display:flex;align-items:center;gap:10px">
        <a class="brand" href={~p"/"}>
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.7"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
            style="color:var(--accent)"
          >
            <path d="M4 5.5A1.5 1.5 0 0 1 5.5 4H10a2 2 0 0 1 2 2v13a2 2 0 0 0-2-2H5.5A1.5 1.5 0 0 1 4 15.5Z" />
            <path d="M20 5.5A1.5 1.5 0 0 0 18.5 4H14a2 2 0 0 0-2 2v13a2 2 0 0 1 2-2h4.5a1.5 1.5 0 0 0 1.5-1.5Z" />
          </svg>
          <span>{@site_name}</span>
        </a>
        <span class="rolebadge">Admin</span>
      </div>

      <div class="pn-nav">
        <.link class="navlink" navigate={~p"/painel"} aria-current="page">Painel</.link>
        <.link class="navlink" navigate={~p"/editor"}>Posts</.link>
      </div>

      <div style="display:flex;align-items:center;gap:8px">
        <a class="navlink" href={~p"/"}>Ver como leitor</a>
        <.link class="btn btn--s" href={~p"/auth/logout"} method="delete">Sair</.link>
      </div>
    </nav>
    """
  end

  attr :totals, :map, required: true
  attr :previous, :map, default: nil
  attr :daily, :list, required: true

  defp kpis(assigns) do
    ~H"""
    <section class="pn-kpis">
      <.kpi
        label="Leituras"
        value={@totals.reads > 0 && numero(@totals.reads)}
        delta={delta(@totals.reads, @previous && @previous.reads, :count)}
        series={Enum.map(@daily, & &1.count)}
        spark_label="Leituras por dia no período."
      />

      <.kpi
        label="Taxa de conclusão"
        value={@totals.completion && "#{@totals.completion}%"}
        delta={delta(@totals.completion, @previous && @previous.completion, :points)}
        hint={"Chegar a #{Analytics.completed_at()}% do artigo conta como concluído."}
      />

      <.kpi
        label="Tempo médio na página"
        value={@totals.avg_seconds && duracao(@totals.avg_seconds)}
        delta={delta(@totals.avg_seconds, @previous && @previous.avg_seconds, :count)}
        hint="Só o tempo com a aba à vista."
      />

      <.kpi
        label="Assinantes"
        value={nil}
        unmeasured="A newsletter ainda não existe, então não há o que contar."
      />
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :delta, :map, default: nil
  attr :series, :list, default: []
  attr :spark_label, :string, default: ""
  attr :hint, :string, default: nil
  attr :unmeasured, :string, default: nil

  defp kpi(assigns) do
    ~H"""
    <div class="card kpi">
      <span class="micro">{@label}</span>

      <span class="kpi-row">
        <span class={["kpi-v", !@value && "kpi-v--none"]}>{@value || "—"}</span>
        <span :if={@delta} class={"delta delta--#{@delta.direction}"}>{@delta.text}</span>
      </span>

      <BlogoWeb.Charts.sparkline :if={@value && @series != []} values={@series} label={@spark_label} />
      <span :if={@unmeasured} class="small kpi-note">{@unmeasured}</span>
      <span :if={@value && @hint} class="small kpi-note">{@hint}</span>
      <span :if={!@value && !@unmeasured} class="small kpi-note">Sem leituras no período.</span>
    </div>
    """
  end

  attr :posts, :list, required: true
  attr :per_post, :map, required: true
  attr :measuring?, :boolean, required: true
  attr :confirmando, :integer, default: nil

  defp post_table(assigns) do
    ~H"""
    <div class="card pn-table-wrap">
      <table class="tbl pn-table">
        <thead>
          <tr>
            <th scope="col">Título</th>
            <th scope="col">Status</th>
            <th scope="col" class="r">Leituras</th>
            <th scope="col" class="r">Conclusão</th>
            <th scope="col"><span class="sr-only">Ações</span></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={post <- @posts}>
            <td data-label="Título">
              {post.title}
              <span class={["small pn-post-meta", parado?(post) && "pn-stalled"]}>
                {meta_do_post(post)}
              </span>
            </td>
            <td data-label="Status">
              <span class={"pill pill--#{pill(post.status)}"}>
                <span class="dot" aria-hidden="true"></span>{estado(post.status)}
              </span>
            </td>
            <td class="r" data-label="Leituras">{leituras(@per_post, post, @measuring?)}</td>
            <td class="r" data-label="Conclusão">{conclusao(@per_post, post, @measuring?)}</td>
            <td class="pn-actions">
              <%= if @confirmando == post.id do %>
                <span class="small pn-confirm">Remover “{post.title}”?</span>
                <button
                  type="button"
                  class="btn btn--sm pn-danger"
                  phx-click="remover"
                  phx-value-id={post.id}
                >
                  Remover
                </button>
                <button type="button" class="btn btn--s btn--sm" phx-click="cancelar_remocao">
                  Cancelar
                </button>
              <% else %>
                <.link class="btn btn--s btn--sm" navigate={~p"/editor/#{post.id}"}>Editar</.link>
                <.link
                  :if={post.status == "published"}
                  class="btn btn--s btn--sm"
                  href={~p"/#{post.slug}"}
                >
                  Ver
                </.link>
                <.link
                  :if={post.status != "published"}
                  class="btn btn--s btn--sm"
                  href={~p"/editor/#{post.id}/previa"}
                >
                  Prévia
                </.link>
                <button
                  :if={post.status == "draft"}
                  type="button"
                  class="btn btn--p btn--sm"
                  phx-click="publicar"
                  phx-value-id={post.id}
                >
                  Publicar
                </button>
                <button
                  :if={post.status == "draft"}
                  type="button"
                  class="btn btn--s btn--sm pn-remove"
                  phx-click="confirmar_remocao"
                  phx-value-id={post.id}
                  aria-label={"Remover #{post.title}"}
                >
                  ×
                </button>
              <% end %>
            </td>
          </tr>

          <tr :if={@posts == []}>
            <td colspan="5" class="small" style="padding:26px;text-align:center">
              Nenhuma publicação nesse filtro.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :site, :map, required: true
  attr :name, :string, required: true
  attr :unnamed?, :boolean, required: true
  attr :form, :map, required: true
  attr :aberto?, :boolean, required: true

  defp site_card(assigns) do
    ~H"""
    <section class="card pn-author">
      <div class="pn-author-head">
        <span>
          <span class="h3">O site</span>
          <span class="small">
            O nome aparece no cabeçalho, no rodapé, no título de cada página e no cartão que
            aparece quando alguém compartilha um link.
          </span>
        </span>
        <button type="button" class="btn btn--s btn--sm" phx-click="site_abrir">
          {if @aberto?, do: "Fechar", else: "Editar"}
        </button>
      </div>

      <p :if={@unnamed? and not @aberto?} class="pn-site-todo">
        Este blog ainda não tem nome. Enquanto isso, o cabeçalho mostra <span class="mono">{@name}</span>, que é o endereço onde ele está.
      </p>

      <div :if={not @unnamed? and not @aberto?} class="pn-author-now">
        <span class="pn-author-name">{@site.name}</span>
        <span :if={@site.description} class="small">{@site.description}</span>
      </div>

      <div class="pn-site-switch">
        <span class="pn-site-switch-text">
          <span class="micro">Figura no card em destaque</span>
          <span class="small">
            Ligada por padrão: o primeiro card da home desenha o diagrama do artigo. Desligada, o
            destaque fica só com o texto — título maior na largura inteira do card. O diagrama
            continua obrigatório no artigo publicado e continua sendo a imagem que aparece quando
            alguém compartilha o link.
          </span>
        </span>

        <span class="seg">
          <button
            :for={{rotulo, ligada} <- [{"Ligada", true}, {"Desligada", false}]}
            type="button"
            class={@site.featured_hero == ligada && "is-on"}
            phx-click="destaque_figura"
            phx-value-ligado={to_string(ligada)}
            aria-pressed={to_string(@site.featured_hero == ligada)}
          >
            {rotulo}
          </button>
        </span>
      </div>

      <.form
        :if={@aberto?}
        id="pn-site-form"
        for={@form}
        phx-change="site_validar"
        phx-submit="site_salvar"
        class="pn-author-form"
      >
        <label class="ed-field pn-author-wide">
          <span class="micro">Nome do site</span>
          <input
            class="input"
            type="text"
            name="site[name]"
            value={@form[:name].value}
            placeholder="O nome que vai no cabeçalho"
          />
          <span :for={msg <- erros(@form[:name])} class="small ed-warn">{msg}</span>
        </label>

        <label class="ed-field pn-author-wide">
          <span class="micro">Descrição</span>
          <textarea
            class="input input--area"
            rows="2"
            name="site[description]"
            placeholder="Uma linha sobre o que se escreve aqui"
          >{@form[:description].value}</textarea>
          <span class="small">
            Vai para a busca e para a prévia do link. Até 160 caracteres.
          </span>
          <span :for={msg <- erros(@form[:description])} class="small ed-warn">{msg}</span>
        </label>

        <div class="pn-author-actions">
          <button type="submit" class="btn btn--p">Salvar</button>
        </div>
      </.form>
    </section>
    """
  end

  attr :author, :map, required: true
  attr :form, :any, required: true
  attr :upload, :any, required: true
  attr :aberto?, :boolean, default: false

  defp author_card(assigns) do
    ~H"""
    <section class="card pn-author">
      <div class="pn-author-head">
        <span>
          <span class="h3">Quem assina</span>
          <span class="small">
            O nome aparece no cabeçalho do site, na assinatura de cada artigo e nos dados
            estruturados que ligam os artigos a você.
          </span>
        </span>
        <button type="button" class="btn btn--s btn--sm" phx-click="autor_abrir">
          {if @aberto?, do: "Fechar", else: "Editar"}
        </button>
      </div>

      <div :if={not @aberto?} class="pn-author-now">
        <BlogoWeb.PostHTML.ava author={@author} class="pn-foto-face" />
        <span class="pn-author-said">
          <span class="pn-author-name">{@author.name}</span>
          <span class="small">{@author.headline}</span>
          <span :if={@author.same_as != []} class="small mono pn-author-links">
            {Enum.join(@author.same_as, " · ")}
          </span>
        </span>
      </div>

      <%!-- Outside the profile form on purpose: a form cannot nest in another
            one, and the upload needs a form of its own to live in. --%>
      <div :if={@aberto?} class="pn-foto">
        <BlogoWeb.PostHTML.ava author={@author} class="pn-foto-face" />

        <div class="pn-foto-side">
          <span class="micro">Foto</span>

          <form id="pn-foto-form" phx-change="foto_escolhida" phx-submit="foto_escolhida">
            <.live_file_input upload={@upload} class="pn-foto-input" />
          </form>

          <span class="small">
            PNG, JPEG ou WebP, até {div(Author.max_photo_bytes(), 1_000_000)} MB. Ela é servida por
            este site, e entra nos dados estruturados como a imagem da pessoa que assina.
          </span>

          <%!-- A foto é pública. Quem sobe uma foto de celular não tem como
                saber que ela carrega a coordenada de onde foi tirada, então a
                tela diz que isso é apagado — e diz o efeito colateral, que é
                a única coisa que a pessoa precisa fazer a respeito. --%>
          <span class="small">
            Os metadados são apagados antes de gravar, inclusive o GPS de onde a foto foi tirada.
            Por isso uma foto que dependia da rotação registrada pelo celular pode sair deitada:
            gire antes de subir.
          </span>

          <span :for={msg <- upload_errors(@upload)} class="small ed-warn">{erro_foto(msg)}</span>

          <div :for={entry <- @upload.entries} class="pn-foto-entry">
            <span :for={msg <- upload_errors(@upload, entry)} class="small ed-warn">
              {erro_foto(msg)}
            </span>
            <button
              :if={upload_errors(@upload, entry) != []}
              type="button"
              class="btn btn--s btn--sm"
              phx-click="foto_descartar"
              phx-value-ref={entry.ref}
            >
              Descartar
            </button>
          </div>

          <button
            :if={Author.photo?(@author)}
            type="button"
            class="btn btn--s btn--sm"
            phx-click="foto_remover"
          >
            Remover foto
          </button>
        </div>
      </div>

      <.form
        :if={@aberto?}
        id="pn-author-form"
        for={@form}
        phx-change="autor_validar"
        phx-submit="autor_salvar"
        class="pn-author-form"
      >
        <label class="ed-field">
          <span class="micro">Nome</span>
          <input class="input" type="text" name="author[name]" value={@form[:name].value} />
          <span :for={msg <- erros(@form[:name])} class="small ed-warn">{msg}</span>
        </label>

        <label class="ed-field">
          <span class="micro">Descrição curta</span>
          <input
            class="input"
            type="text"
            name="author[headline]"
            value={@form[:headline].value}
            placeholder="Engenheiro de software"
          />
        </label>

        <label class="ed-field">
          <span class="micro">Cidade</span>
          <input class="input" type="text" name="author[city]" value={@form[:city].value} />
        </label>

        <label class="ed-field pn-author-wide">
          <span class="micro">Bio</span>
          <textarea class="input input--area" rows="3" name="author[bio]">{@form[:bio].value}</textarea>
        </label>

        <label class="ed-field pn-author-wide">
          <span class="micro">Perfis (um por linha)</span>
          <textarea
            class="input input--area mono"
            rows="3"
            name="author[same_as_text]"
            placeholder="https://github.com/…"
          >{same_as_text(@form)}</textarea>
          <span class="small">
            É o que diz a um buscador que estes perfis e estes artigos são a mesma pessoa.
          </span>
          <span :for={msg <- erros(@form[:same_as])} class="small ed-warn">{msg}</span>
        </label>

        <div class="pn-author-slug">
          <span class="micro">Endereço</span>
          <span class="small mono">/autor/{@author.slug}</span>
          <span class="small">
            Não muda por aqui: ele identifica você nos dados estruturados de todos os artigos,
            e trocá-lo faz um buscador ver outra pessoa.
          </span>
        </div>

        <div class="pn-author-actions">
          <button type="submit" class="btn btn--p">Salvar</button>
        </div>
      </.form>
    </section>
    """
  end

  # O LiveView recusa o arquivo antes de ele chegar inteiro; a mensagem dele é
  # um átomo, e quem lê a tela não fala átomo.
  defp erro_foto(:too_large),
    do: "A foto passa de #{div(Author.max_photo_bytes(), 1_000_000)} MB."

  defp erro_foto(:not_accepted), do: "Formato não aceito: PNG, JPEG ou WebP."
  defp erro_foto(:too_many_files), do: "Uma foto por vez."
  defp erro_foto(other), do: to_string(other)

  defp erros(field) do
    Enum.map(field.errors, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), "") |> to_string()
      end)
    end)
  end

  defp same_as_text(form) do
    case form[:same_as].value do
      list when is_list(list) -> Enum.join(list, "\n")
      _ -> ""
    end
  end

  attr :kind, :atom, required: true

  defp queue_icon(assigns) do
    ~H"""
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <%= case @kind do %>
        <% :stalled -> %>
          <circle cx="12" cy="12" r="8.5" /><path d="M12 8v4.5" /><path d="M12 16h.01" />
        <% :broken_link -> %>
          <path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.5 1.5" /><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7L12 19" />
        <% _ -> %>
          <circle cx="12" cy="12" r="8.5" />
      <% end %>
    </svg>
    """
  end

  # ── wording ───────────────────────────────────────────────────────────────

  defp periods, do: @periods

  defp periodo_label(:all), do: "Desde o começo"
  defp periodo_label(n), do: "Últimos #{n} dias"

  defp resumo(counts) do
    [
      {Map.get(counts, "published", 0), "publicado", "publicados"},
      {Map.get(counts, "draft", 0), "rascunho", "rascunhos"},
      {Map.get(counts, "scheduled", 0), "agendado", "agendados"}
    ]
    |> Enum.reject(fn {n, _s, _p} -> n == 0 end)
    |> case do
      [] ->
        "Nenhuma publicação ainda"

      parts ->
        Enum.map_join(parts, " · ", fn {n, s, p} -> "#{n} #{if n == 1, do: s, else: p}" end)
    end
  end

  defp filtrar(posts, "todos"), do: posts
  defp filtrar(posts, status), do: Enum.filter(posts, &(&1.status == status))

  defp parado?(%{status: "draft", updated_at: at}),
    do: DateTime.diff(DateTime.utc_now(), at, :day) >= 14

  defp parado?(_post), do: false

  defp pill("published"), do: "live"
  defp pill("scheduled"), do: "sched"
  defp pill(_), do: "draft"

  defp estado("published"), do: "Publicado"
  defp estado("scheduled"), do: "Agendado"
  defp estado(_), do: "Rascunho"

  # A post that was never published has no reads by definition, which is not
  # the same as a published post nobody opened. The dash says "does not apply";
  # a zero would say "nobody", and only one of those is a fact.
  defp leituras(_per_post, %{status: status}, _measuring?) when status != "published", do: "—"
  defp leituras(_per_post, _post, false), do: "—"

  defp leituras(per_post, post, true) do
    case Map.get(per_post, post.id) do
      nil -> "0"
      %{reads: reads} -> numero(reads)
    end
  end

  defp conclusao(_per_post, %{status: status}, _measuring?) when status != "published", do: "—"
  defp conclusao(_per_post, _post, false), do: "—"

  defp conclusao(per_post, post, true) do
    case Map.get(per_post, post.id) do
      %{completion: pct} when is_integer(pct) -> "#{pct}%"
      _ -> "—"
    end
  end

  defp meta_do_post(%{status: "published"} = post) do
    "#{data_curta(post.published_at)} · #{post.reading_minutes || 1} min"
  end

  defp meta_do_post(%{status: "scheduled"} = post) do
    "agendado para #{data_curta(post.published_at)}"
  end

  defp meta_do_post(post) do
    parado = DateTime.diff(DateTime.utc_now(), post.updated_at, :day)

    if parado >= 14,
      do: "rascunho · parado #{ha_quanto(post.updated_at)}",
      else: "rascunho · editado #{ha_quanto(post.updated_at)}"
  end

  @meses ~w(jan fev mar abr mai jun jul ago set out nov dez)

  defp data_curta(nil), do: "sem data"

  defp data_curta(%Date{} = d), do: "#{d.day} #{Enum.at(@meses, d.month - 1)}"

  defp data_curta(%DateTime{} = d), do: "#{d.day} #{Enum.at(@meses, d.month - 1)}"

  defp ha_quanto(nil), do: "há pouco"

  defp ha_quanto(%DateTime{} = t) do
    case DateTime.diff(DateTime.utc_now(), t, :day) do
      0 -> "hoje"
      1 -> "ontem"
      n when n < 30 -> "há #{n} dias"
      n -> "há #{div(n, 30)} meses"
    end
  end

  defp janela_maior_que_coleta?(since, days) when is_integer(days) do
    Date.diff(Date.utc_today(), since) < days - 1
  end

  defp janela_maior_que_coleta?(_since, _period), do: false

  defp duracao(seconds) when seconds < 60, do: "#{seconds}s"

  defp duracao(seconds),
    do: "#{div(seconds, 60)}m#{String.pad_leading("#{rem(seconds, 60)}", 2, "0")}"

  defp numero(nil), do: "—"

  defp numero(n) do
    n
    |> to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1.")
    |> String.reverse()
  end

  # A delta against nothing is not zero per cent, it is no comparison. The
  # first thirty days of a blog would otherwise show "+100%" on every card.
  defp delta(_now, nil, _kind), do: nil
  defp delta(nil, _before, _kind), do: nil
  defp delta(_now, 0, :count), do: nil

  defp delta(now, before, :count) when is_integer(now) and is_integer(before) do
    change = round((now - before) * 100 / before)
    %{direction: direction(change), text: "#{abs(change)}%"}
  end

  defp delta(now, before, :points) when is_integer(now) and is_integer(before) do
    change = now - before
    %{direction: direction(change), text: "#{abs(change)} pp"}
  end

  defp delta(_now, _before, _kind), do: nil

  defp direction(change) when change > 0, do: "up"
  defp direction(change) when change < 0, do: "down"
  defp direction(_change), do: "flat"
end
