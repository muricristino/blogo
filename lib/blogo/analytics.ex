defmodule Blogo.Analytics do
  @moduledoc """
  What the blog knows about being read.

  Two rules run through this module, and both exist because a panel is read as
  fact even when it is a guess:

    * **Nothing is inferred.** Every figure here is counted from rows in
      `reads`. Where there is no measurement there is no number — the caller
      gets `nil` and the screen says so in words, rather than a zero that
      reads as "nobody came".
    * **A read is a page view, not a person.** No identifier is stored, so
      "1.200 leituras" never becomes "1.200 leitores" anywhere in the wording.

  Reads only exist because a browser ran JavaScript and reported back, which
  also means crawlers are mostly absent from these numbers — useful, and worth
  knowing when comparing them against a server log.
  """

  import Ecto.Query, warn: false

  alias Blogo.Analytics.Read
  alias Blogo.Content.Post
  alias Blogo.Repo

  # Reaching ninety per cent of the page is "finished": an article ends above
  # its own footer, so a reader who read every word rarely touches 100.
  @completed_at 90

  @doc """
  Records one read. `attrs` come from the browser and are clamped by the
  changeset.
  """
  def record_read(post_id, attrs) do
    %Read{}
    |> Read.changeset(
      attrs
      |> Map.put(:post_id, post_id)
      |> Map.put_new(:day, Date.utc_today())
    )
    |> Repo.insert()
  end

  @doc """
  Classifies where a read came from.

  `utm_source` wins when present, because that is the only way a newsletter or
  a campaign can identify itself; otherwise the referrer's host decides.
  """
  def classify(referrer, utm_source \\ nil, own_host \\ nil)

  def classify(_referrer, utm, _own) when is_binary(utm) and utm != "" do
    case String.downcase(utm) do
      "newsletter" <> _ -> "newsletter"
      "email" <> _ -> "newsletter"
      s when s in ~w(google bing duckduckgo ecosia) -> "busca"
      s when s in ~w(linkedin twitter x facebook instagram reddit bluesky) -> "redes"
      _ -> "outros"
    end
  end

  def classify(referrer, _utm, own_host) do
    case host_of(referrer) do
      nil -> "direto"
      host when host == own_host -> "interno"
      host -> classify_host(host)
    end
  end

  defp classify_host(host) do
    cond do
      host =~ ~r/(^|\.)(google|bing|duckduckgo|ecosia|yahoo|search\.brave|startpage)\./ ->
        "busca"

      host =~ ~r/(^|\.)(linkedin|twitter|x|facebook|instagram|reddit|bsky|t)\.(com|app|co|me)/ ->
        "redes"

      host =~ ~r/news\.ycombinator\.com/ ->
        "redes"

      true ->
        "outros"
    end
  end

  defp host_of(nil), do: nil
  defp host_of(""), do: nil

  defp host_of(referrer) when is_binary(referrer) do
    case URI.parse(referrer) do
      %URI{host: host} when is_binary(host) and host != "" -> String.downcase(host)
      _ -> nil
    end
  end

  defp host_of(_), do: nil

  # ── the panel's questions ─────────────────────────────────────────────────

  @doc """
  The window a panel is looking at. `:all` has no lower bound.
  """
  def window(:all), do: {~D[1970-01-01], Date.utc_today()}

  def window(days) when is_integer(days) do
    today = Date.utc_today()
    {Date.add(today, -(days - 1)), today}
  end

  @doc """
  The window immediately before this one, of the same length — the only honest
  basis for "18% a mais than what?".
  """
  def previous_window(:all), do: nil

  def previous_window(days) when is_integer(days) do
    {from, _to} = window(days)
    {Date.add(from, -days), Date.add(from, -1)}
  end

  @doc """
  Headline figures for a window. `nil` for a figure means there is nothing to
  average — no reads — and the caller must not render it as zero.
  """
  def totals(range) do
    from(r in Read,
      where: ^where_range(range),
      select: %{
        reads: count(r.id),
        completed: fragment("count(*) filter (where ? >= ?)", r.depth, ^@completed_at),
        seconds: avg(r.seconds)
      }
    )
    |> Repo.one()
    |> then(fn row ->
      %{
        reads: row.reads,
        completion: percentage(row.completed, row.reads),
        avg_seconds: average_seconds(row.seconds, row.reads)
      }
    end)
  end

  @doc """
  Reads per day across the window, with the days nobody read filled in as zero
  — a gap in a bar chart reads as "no data", and zero is what actually
  happened.
  """
  def daily(range) do
    {from_day, to_day} = range

    counted =
      from(r in Read,
        where: ^where_range(range),
        group_by: r.day,
        select: {r.day, count(r.id)}
      )
      |> Repo.all()
      |> Map.new()

    Date.range(from_day, to_day)
    |> Enum.map(fn day -> %{day: day, count: Map.get(counted, day, 0)} end)
  end

  @doc """
  Where the reads came from, biggest first.
  """
  def sources(range) do
    rows =
      from(r in Read,
        where: ^where_range(range),
        group_by: r.source,
        order_by: [desc: count(r.id)],
        select: {r.source, count(r.id)}
      )
      |> Repo.all()

    total = rows |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    Enum.map(rows, fn {source, count} ->
      %{source: source, count: count, pct: percentage(count, total)}
    end)
  end

  @doc """
  How far readers got, as the share still on the page at each tenth of the
  article.

  Starts at 100 by definition, which is why the first point is not a
  measurement. It ends at `@completed_at` rather than at 100 so that the last
  point *is* the completion rate — the same fact stated twice on one screen has
  to be the same number, and literal 100% scroll means touching the footer.
  """
  def depth_curve(range) do
    total = Repo.one(from(r in Read, where: ^where_range(range), select: count(r.id)))

    if total == 0 do
      []
    else
      for tenth <- 0..9 do
        depth = tenth * 10

        still =
          Repo.one(
            from(r in Read,
              where: ^where_range(range),
              where: r.depth >= ^depth,
              select: count(r.id)
            )
          )

        %{depth: depth, pct: percentage(still, total)}
      end
    end
  end

  @doc """
  The steepest fall in the depth curve, in words — the one sentence the panel
  can honestly write under that chart.
  """
  def steepest_drop(curve) when length(curve) < 2, do: nil

  def steepest_drop(curve) do
    curve
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> {a.depth, b.depth, a.pct - b.pct} end)
    |> Enum.max_by(fn {_from, _to, drop} -> drop end)
    |> case do
      {_from, _to, drop} when drop <= 0 -> nil
      {from, to, drop} -> %{from: from, to: to, drop: drop}
    end
  end

  @doc """
  Reads and completion for each post in the window, keyed by post id. A post
  with no reads is absent rather than zero, so the caller decides how to show
  "not read yet" against "not measured".
  """
  def by_post(range) do
    from(r in Read,
      where: ^where_range(range),
      group_by: r.post_id,
      select: {
        r.post_id,
        %{
          reads: count(r.id),
          completed: fragment("count(*) filter (where ? >= ?)", r.depth, ^@completed_at)
        }
      }
    )
    |> Repo.all()
    |> Map.new(fn {post_id, row} ->
      {post_id, %{reads: row.reads, completion: percentage(row.completed, row.reads)}}
    end)
  end

  @doc """
  Whether anything at all has ever been recorded. The panel needs this to tell
  "nobody read it" apart from "nothing is being measured yet", which look
  identical in every individual figure.
  """
  def measuring?, do: Repo.exists?(Read)

  @doc """
  The day collection started, or nil. A figure covering thirty days when only
  three have been collected is not wrong, but it is misleading without this.
  """
  def collecting_since do
    Repo.one(from(r in Read, select: min(r.day)))
  end

  def completed_at, do: @completed_at

  defp where_range({from_day, to_day}) do
    dynamic([r], r.day >= ^from_day and r.day <= ^to_day)
  end

  defp average_seconds(_avg, 0), do: nil
  defp average_seconds(nil, _reads), do: nil
  defp average_seconds(avg, _reads), do: round(Decimal.to_float(avg))

  defp percentage(_part, 0), do: nil
  defp percentage(_part, nil), do: nil
  defp percentage(part, total), do: round(part * 100 / total)

  # ── the queue ─────────────────────────────────────────────────────────────

  @stalled_after_days 30

  @doc """
  What is waiting on the author, as a list of `%{kind, text, action, href}`.

  Only things that can actually be checked appear. Comments and the newsletter
  do not exist yet, so the panel does not carry a row for them: an item that
  can never be true is a permanent piece of furniture that teaches the eye to
  skip the list.
  """
  def queue do
    Enum.reject([stalled_drafts(), broken_internal_links()], &is_nil/1)
  end

  defp stalled_drafts do
    cutoff = DateTime.add(DateTime.utc_now(), -@stalled_after_days * 86_400, :second)

    drafts =
      from(p in Post,
        where: p.status == "draft" and p.updated_at < ^cutoff,
        order_by: [asc: p.updated_at],
        select: %{id: p.id, title: p.title}
      )
      |> Repo.all()

    case drafts do
      [] ->
        nil

      [only] ->
        %{
          kind: :stalled,
          text: "Um rascunho parado há mais de #{@stalled_after_days} dias",
          action: "Retomar “#{only.title}”",
          href: "/editor/#{only.id}"
        }

      [oldest | _] = all ->
        %{
          kind: :stalled,
          text: "#{length(all)} rascunhos parados há mais de #{@stalled_after_days} dias",
          action: "Retomar o mais antigo",
          href: "/editor/#{oldest.id}"
        }
    end
  end

  @doc """
  Internal links in published articles that point at nothing.

  Only internal ones: they 404 a real reader, they are the author's own fault,
  and they can be answered from the database. Checking external links means an
  outbound crawler with its own cache and schedule, which is a feature rather
  than a line in a list.
  """
  def broken_internal_links do
    published =
      from(p in Post, where: p.status == "published", select: %{title: p.title, body: p.body})
      |> Repo.all()

    live_slugs =
      from(p in Post, where: p.status == "published", select: p.slug)
      |> Repo.all()
      |> MapSet.new()

    broken =
      for post <- published,
          slug <- internal_link_slugs(post.body),
          not MapSet.member?(live_slugs, slug),
          do: {post.title, slug}

    case broken do
      [] ->
        nil

      [{title, slug}] ->
        %{
          kind: :broken_link,
          text: "Um link interno quebrado em “#{title}”: /#{slug}",
          action: nil,
          href: nil
        }

      list ->
        %{
          kind: :broken_link,
          text: "#{length(list)} links internos quebrados",
          action: nil,
          href: nil
        }
    end
  end

  # Links live inside the inline dialect (`[texto](/endereco)`) anywhere a
  # block holds prose, so the body is searched as text rather than walked
  # block by block — a new block type would otherwise silently stop being
  # checked.
  defp internal_link_slugs(body) when is_map(body) do
    body
    |> Jason.encode!()
    |> then(&Regex.scan(~r/\]\((\/[a-z0-9\-\/]*)\)/i, &1))
    |> Enum.map(fn [_full, path] ->
      path |> String.trim_leading("/") |> String.trim_trailing("/")
    end)
    |> Enum.reject(&(&1 == "" or String.contains?(&1, "/")))
    |> Enum.uniq()
  end

  defp internal_link_slugs(_body), do: []
end
