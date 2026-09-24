defmodule Blogo.Repo.Migrations.PublishLearnoArticle do
  use Ecto.Migration

  @moduledoc """
  Publishes the article about the learno skill.

  Content arrives as a migration because seeds only run on an empty database and
  this blog already has articles in production. The text itself lives in
  `priv/repo/articles/learno.exs` — thirty blocks inside a migration is thirty
  blocks nobody reviews.

  Guarded by the address, so running it twice changes nothing — and skipped
  entirely when there is no author, which is what a fresh install of this
  self-hosted tool looks like. Somebody else's blogo should not come with an
  article written for this one.
  """

  import Ecto.Query

  def up do
    article =
      Application.app_dir(:blogo, "priv/repo/articles/learno.exs")
      |> Code.eval_file()
      |> elem(0)

    repo().one(from(p in "posts", where: p.slug == ^article.slug, select: count()))
    |> case do
      0 -> insert(article)
      _ -> :ok
    end
  end

  def down, do: :ok

  defp insert(article) do
    case repo().one(from(a in "authors", order_by: a.id, limit: 1, select: a.id)) do
      nil -> :ok
      author_id -> insert(article, author_id)
    end
  end

  defp insert(article, author_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    repo().insert_all("posts", [
      %{
        title: article.title,
        subtitle: article.subtitle,
        slug: article.slug,
        kind: article.kind,
        status: "published",
        published_at: now,
        reading_minutes: article.reading_minutes,
        topics: article.topics,
        meta_description: article.meta_description,
        body: %{"blocks" => article.blocks},
        hero: article.hero,
        author_id: author_id,
        lock_version: 1,
        inserted_at: now,
        updated_at: now
      }
    ])
  end
end
