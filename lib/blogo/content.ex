defmodule Blogo.Content do
  @moduledoc "Reading and writing posts and their authors."

  import Ecto.Query, warn: false
  alias Blogo.Repo
  alias Blogo.Content.{Author, Post}

  def list_published do
    from(p in Post,
      where: p.status == "published" and p.published_at <= ^DateTime.utc_now(),
      order_by: [desc: p.published_at],
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

  def create_author(attrs), do: %Author{} |> Author.changeset(attrs) |> Repo.insert()
  def create_post(attrs), do: %Post{} |> Post.changeset(attrs) |> Repo.insert()

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
      post |> Post.changeset(attrs) |> Repo.update()
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

  defp reading_minutes(attrs, post) do
    blocks =
      case attrs do
        %{body: %{"blocks" => blocks}} -> blocks
        _ -> post.body["blocks"] || []
      end

    Blogo.Content.Metrics.reading_minutes(blocks)
  end
end
