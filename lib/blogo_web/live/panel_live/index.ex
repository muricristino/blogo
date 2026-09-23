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

  @periods [{7, "7 dias"}, {30, "30 dias"}, {90, "90 dias"}, {:all, "Tudo"}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Painel",
       # The admin stylesheet is keyed on this flag; the panel is the same
       # surface as the editor and shares `.bar`, `.card` and `.btn`.
       editor?: true,
       period: 30,
       filter: "todos"
     )
     |> load()}
  end

  @impl true
  def handle_event("period", %{"value" => value}, socket) do
    {:noreply, socket |> assign(period: parse_period(value)) |> load()}
  end

  def handle_event("filter", %{"value" => value}, socket) do
    {:noreply, assign(socket, filter: value)}
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
      <.topbar />

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
              phx-value-value={to_string(value)}
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
                  phx-value-value={value}
                >
                  {label}
                </button>
              </span>
            </div>

            <.post_table
              posts={filtrar(@posts, @filter)}
              per_post={@per_post}
              measuring?={@measuring?}
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
          <span>blogo</span>
        </a>
        <span class="rolebadge">Admin</span>
      </div>

      <div class="pn-nav">
        <.link class="navlink" navigate={~p"/painel"} aria-current="page">Painel</.link>
        <.link class="navlink" navigate={~p"/editor"}>Posts</.link>
      </div>

      <div style="display:flex;align-items:center;gap:8px">
        <a class="navlink pn-asreader" href={~p"/"}>Ver como leitor</a>
        <.link class="btn btn--s" href={~p"/sair"} method="delete">Sair</.link>
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
        <span class={"kpi-v #{!@value && "kpi-v--none"}"}>{@value || "—"}</span>
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
              <span class="small pn-post-meta">{meta_do_post(post)}</span>
            </td>
            <td data-label="Status">
              <span class={"pill pill--#{pill(post.status)}"}>
                <span class="dot" aria-hidden="true"></span>{estado(post.status)}
              </span>
            </td>
            <td class="r" data-label="Leituras">{leituras(@per_post, post, @measuring?)}</td>
            <td class="r" data-label="Conclusão">{conclusao(@per_post, post, @measuring?)}</td>
            <td class="pn-actions">
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

  defp meta_do_post(post), do: "rascunho · editado #{ha_quanto(post.updated_at)}"

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
