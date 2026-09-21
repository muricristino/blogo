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
end
