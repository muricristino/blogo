defmodule Blogo.Repo.Migrations.AboutPageFromAuthor do
  use Ecto.Migration

  @moduledoc """
  Turns the old author page into a real page.

  `/autor/:slug` rendered the author's headline and bio through a template of
  its own. That template is gone, so without this the nav would simply lose its
  "Sobre" link and what was written there would stop being reachable — a
  regression in content dressed up as a refactor.

  The page is created from what the author already has, published, so the site
  keeps saying what it said yesterday. From here it is edited like any article.

  Skipped when there is no author, or when a page already exists.
  """

  import Ecto.Query

  def up do
    with author when not is_nil(author) <- first_author(),
         0 <- page_count() do
      insert(author)
    else
      _ -> :ok
    end
  end

  def down, do: :ok

  defp first_author do
    repo().one(
      from(a in "authors",
        order_by: a.id,
        limit: 1,
        select: %{id: a.id, name: a.name, headline: a.headline, bio: a.bio, city: a.city}
      )
    )
  end

  defp page_count do
    repo().one(from(p in "posts", where: p.kind == "pagina", select: count()))
  end

  defp insert(author) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    repo().insert_all("posts", [
      %{
        title: "Sobre",
        subtitle: author.headline,
        slug: "sobre",
        kind: "pagina",
        status: "published",
        published_at: now,
        reading_minutes: 1,
        topics: [],
        meta_description: author.bio,
        body: %{"blocks" => blocks(author)},
        author_id: author.id,
        lock_version: 1,
        inserted_at: now,
        updated_at: now
      }
    ])
  end

  defp blocks(author) do
    [
      %{"type" => "text", "paragraphs" => Enum.reject([author.bio], &is_nil/1)},
      %{
        "type" => "text",
        "paragraphs" => Enum.reject([author.city && "Escrevo de #{author.city}."], &is_nil/1)
      }
    ]
    |> Enum.reject(&(&1["paragraphs"] == []))
  end
end
