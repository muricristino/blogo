defmodule Blogo.Content do
  @moduledoc "Reading and writing posts and their authors."

  import Ecto.Query, warn: false
  alias Blogo.Repo
  alias Blogo.Content.{Author, Post, PostSlug, Site}

  @doc """
  The published articles, newest first.

  Fixed pages are excluded here rather than at each call site: the index, the
  feed and the topic pages all ask this question, and a page that showed up in
  any of them would be a page pretending to be an article.
  """
  def list_published do
    from(p in Post,
      where:
        p.status == "published" and p.published_at <= ^DateTime.utc_now() and
          p.kind != "pagina",
      order_by: [desc: p.published_at],
      preload: [:author]
    )
    |> Repo.all()
  end

  @doc """
  The published fixed pages, in the order they were published — which is the
  order the navigation shows them in.
  """
  def list_pages do
    from(p in Post,
      where:
        p.status == "published" and p.published_at <= ^DateTime.utc_now() and
          p.kind == "pagina",
      order_by: [asc: p.published_at],
      preload: [:author]
    )
    |> Repo.all()
  end

  def get_published_by_slug(slug) do
    from(p in Post,
      where: p.slug == ^slug and p.status == "published",
      preload: [:author]
    )
    |> Repo.one()
  end

  def get_author_by_slug(slug), do: Repo.get_by(Author, slug: slug)

  # ── the site itself ───────────────────────────────────────────────────────

  @doc """
  What this installation calls itself. Always returns a struct: an install that
  has never been configured gets an empty one rather than nil, so no caller has
  to guard and no page can crash on a fresh database.
  """
  def the_site do
    case Repo.get(Site, 1) do
      nil -> %Site{id: 1}
      site -> site
    end
  end

  def update_site(attrs) do
    case Repo.get(Site, 1) do
      nil -> %Site{id: 1} |> Site.changeset(attrs) |> Repo.insert()
      site -> site |> Site.changeset(attrs) |> Repo.update()
    end
  end

  def change_site(%Site{} = site, attrs \\ %{}), do: Site.changeset(site, attrs)

  @doc """
  The name to show. Falls back to the host, which is a fact about where this
  install lives rather than a name somebody invented for it.
  """
  def site_name(%Site{} = site) do
    if Site.unnamed?(site), do: default_site_name(), else: site.name
  end

  @doc """
  The language this blog writes in: the one most of its published posts are in.

  Counted rather than configured. A post already says which language it is in,
  and a second place to declare the same fact is a second place for it to be
  wrong — an install that starts publishing in English says so here without
  anyone remembering to flip a setting. `pt-BR` while nothing is published,
  because that is what the first posts here were written in.
  """
  def site_language do
    from(p in Post,
      where: p.status == "published",
      group_by: p.language,
      order_by: [desc: count(p.id)],
      limit: 1,
      select: p.language
    )
    |> Repo.one()
    |> Kernel.||("pt-BR")
  end

  defp default_site_name do
    BlogoWeb.Endpoint.url() |> URI.parse() |> Map.get(:host) || "blog"
  end

  def create_author(attrs), do: %Author{} |> Author.changeset(attrs) |> Repo.insert()
  def create_post(attrs), do: %Post{} |> Post.changeset(attrs) |> Repo.insert()

  @doc """
  The author this blog belongs to. A single-author blog by design, so the first
  row is the answer; the panel edits this one.
  """
  def the_author, do: Author |> order_by(asc: :id) |> limit(1) |> Repo.one()

  def get_author!(id), do: Repo.get!(Author, id)

  def update_author(%Author{} = author, attrs) do
    author |> Author.profile_changeset(attrs) |> Repo.update()
  end

  def change_author(%Author{} = author, attrs \\ %{}) do
    Author.profile_changeset(author, attrs)
  end

  @doc """
  Stores the uploaded photo. The bytes go to the database because the container
  they arrive in is replaced on every deploy and has no volume mounted.
  """
  def put_author_photo(%Author{} = author, bytes) when is_binary(bytes) do
    author |> Author.photo_changeset(bytes) |> Repo.update()
  end

  def delete_author_photo(%Author{} = author) do
    author |> Author.no_photo_changeset() |> Repo.update()
  end

  @doc """
  The photo bytes and what to serve them as, fetched on their own.

  `:photo` is declared `load_in_query: false`, so no other query in the
  application carries the image around; this is the only place that asks for
  it. Returns nil when the author has no photo, or does not exist.
  """
  def author_photo(slug) do
    from(a in Author,
      where: a.slug == ^slug and not is_nil(a.photo),
      select: %{data: a.photo, type: a.photo_type, digest: a.photo_digest}
    )
    |> Repo.one()
  end

  def upsert_author(attrs) do
    case get_author_by_slug(attrs.slug) do
      nil -> create_author(attrs)
      author -> author |> Author.changeset(attrs) |> Repo.update()
    end
  end

  def upsert_post(attrs) do
    case Repo.get_by(Post, slug: attrs.slug) do
      nil -> create_post(attrs)
      post -> post |> Post.changeset(attrs) |> Repo.update()
    end
  end

  # ── the editor ────────────────────────────────────────────────────────────

  @doc """
  Every post the editor lists, drafts first — a draft is the one that needs
  attention, and burying it under what is already published is backwards.
  """
  def list_posts do
    from(p in Post,
      order_by: [asc: fragment("? = 'published'", p.status), desc: p.updated_at],
      preload: [:author]
    )
    |> Repo.all()
  end

  def get_post!(id), do: Post |> Repo.get!(id) |> Repo.preload(:author)

  @doc """
  Starts a draft. It has no slug and no body yet, so it cannot be published
  until someone writes one — which is what `Post.changeset/2` enforces.
  """
  def new_draft(author_id) do
    create_post(%{
      title: "Sem título",
      slug: "rascunho-#{System.unique_integer([:positive])}",
      status: "draft",
      kind: "ensaio",
      # One empty paragraph, so a new draft opens with somewhere to type instead
      # of a blank sheet whose only affordance is a dashed button.
      body: %{"blocks" => [%{"type" => "text", "paragraphs" => [""]}]},
      author_id: author_id
    })
  end

  @doc """
  Saves the draft. Reading time is recomputed from the body on every save, so
  it can never be a number someone typed once and forgot.
  """
  def save_post(%Post{} = post, attrs) do
    attrs = Map.put(attrs, :reading_minutes, reading_minutes(attrs, post))

    try do
      case post |> Post.changeset(attrs) |> Repo.update() do
        {:ok, saved} -> {:ok, remember_slug(post, saved)}
        other -> other
      end
    rescue
      # The row moved under us — someone else saved between our read and our
      # write. Returning it as a value lets the caller tell the writer instead
      # of crashing the editor with their article in it.
      Ecto.StaleEntryError -> {:error, :stale}
    end
  end

  @doc """
  Publishes. `published_at` is only set the first time, so re-publishing an
  edit does not move the article back to the top of the index and does not
  rewrite the date a reader already saw.
  """
  def publish_post(%Post{} = post, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:status, "published")
      |> Map.put_new_lazy(:published_at, fn ->
        post.published_at || DateTime.utc_now() |> DateTime.truncate(:second)
      end)

    save_post(post, attrs)
  end

  @doc """
  Takes a published article back to draft. The address is kept, so republishing
  restores the same URL rather than orphaning the links that already point at it.
  """
  def unpublish_post(%Post{} = post), do: save_post(post, %{status: "draft"})

  @doc """
  Deletes a draft.

  Only a draft: a published article has an address someone may have linked, and
  deleting it turns that link into a 404 with nothing to put in its place. To
  remove one, unpublish it first — which is a decision with a step of its own.
  """
  def delete_draft(%Post{status: "published"}), do: {:error, :published}

  def delete_draft(%Post{} = post), do: Repo.delete(post)

  # ── addresses an article used to have ─────────────────────────────────────

  @doc """
  The article that used to live at this address, if any.

  Only published articles redirect: a draft's old address was never public, so
  pointing at it would leak that the draft exists.
  """
  def post_by_former_slug(slug) do
    from(s in PostSlug,
      join: p in assoc(s, :post),
      where: s.slug == ^slug and p.status == "published",
      select: p
    )
    |> Repo.one()
  end

  # Keeping the address an article is leaving means a link someone else made
  # years ago still lands. Conflicts are ignored on purpose: an address can only
  # belong to one article, and the first claim is the one that is already out
  # in the world.
  defp remember_slug(%Post{slug: before}, %Post{slug: before} = saved), do: saved

  defp remember_slug(%Post{slug: before, id: id}, %Post{} = saved) when is_binary(before) do
    Repo.insert_all(
      PostSlug,
      [
        [post_id: id, slug: before, inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)]
      ],
      on_conflict: :nothing
    )

    saved
  end

  defp remember_slug(_before, saved), do: saved

  # ── topics ────────────────────────────────────────────────────────────────

  @doc """
  Every topic that has at least one published article, with its count and the
  address its page lives at.
  """
  def list_topics do
    list_published()
    |> Enum.flat_map(& &1.topics)
    |> Enum.frequencies()
    |> Enum.map(fn {name, count} -> %{name: name, slug: topic_slug(name), count: count} end)
    |> Enum.sort_by(&{-&1.count, &1.name})
  end

  @doc """
  The articles filed under a topic, found by the slug in the address.

  Topics are free text a writer types, so the slug is derived rather than
  stored — which also means two topics that differ only by accent share a page,
  and that is the right answer for a reader.
  """
  def posts_by_topic_slug(slug) do
    posts =
      Enum.filter(list_published(), fn p -> Enum.any?(p.topics, &(topic_slug(&1) == slug)) end)

    name =
      posts
      |> Enum.flat_map(& &1.topics)
      |> Enum.find(&(topic_slug(&1) == slug))

    case posts do
      [] -> nil
      _ -> %{name: name, slug: slug, posts: posts}
    end
  end

  @doc "The address a topic's page lives at: accents folded, spaces hyphenated."
  def topic_slug(name) do
    name
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-zA-Z0-9\s-]/u, "")
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
  end

  defp reading_minutes(attrs, post) do
    blocks =
      case attrs do
        %{body: %{"blocks" => blocks}} -> blocks
        _ -> post.body["blocks"] || []
      end

    Blogo.Content.Metrics.reading_minutes(blocks)
  end
end
