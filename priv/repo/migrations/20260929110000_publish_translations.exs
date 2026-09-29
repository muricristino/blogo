defmodule Blogo.Repo.Migrations.PublishTranslations do
  @moduledoc """
  The English and Spanish versions of the articles that already exist.

  Reads the data files rather than carrying thirty blocks of prose inside a
  migration, for the same reason the learno article does: text in a migration is
  text nobody reviews.

  Idempotent by slug, and it skips anything whose Portuguese original is not
  there — a fresh database runs the seeds in some other order, and a migration
  that raises because an article is missing is a deploy that does not boot.
  """
  use Ecto.Migration
  import Ecto.Query

  def up do
    Enum.each(short_ones() ++ long_ones(), &insert/1)
  end

  # The short articles are a few blocks each, so they are written as data.
  defp short_ones do
    Enum.flat_map(~w(translations_en.exs translations_es.exs), fn file ->
      case read(file) do
        nil -> []
        {list, _} -> list
      end
    end)
  end

  # The long ones are written as markdown and parsed by the same code the editor
  # uses, so their thirty blocks — tables, diagrams, margin notes — do not have
  # to be hand-assembled into maps, and the round trip that is already tested is
  # what proves they came out right.
  #
  # The hero is not in the markdown: it is a column, and it has words inside it,
  # so it comes from its own file.
  defp long_ones do
    heroes =
      case read("heroes_translated.exs") do
        nil -> %{}
        {map, _} -> map
      end

    for {file, of, language} <- [
          {"laya-x-jev.en.md", "laya-x-jev", "en"},
          {"laya-x-jev.es.md", "laya-x-jev", "es"},
          {"fluencia.en.md", "fluencia-e-facil-de-fingir", "en"},
          {"fluencia.es.md", "fluencia-e-facil-de-fingir", "es"}
        ],
        path = Application.app_dir(:blogo, "priv/repo/articles/#{file}"),
        File.exists?(path),
        {:ok, meta} = Blogo.Content.Markdown.from_markdown(File.read!(path)) do
      %{
        of: of,
        language: language,
        slug: meta.slug,
        title: meta.title,
        subtitle: meta.subtitle,
        topics: meta.topics || [],
        meta_description: meta.meta_description,
        hero: Map.get(heroes, meta.slug),
        blocks: meta.body["blocks"]
      }
    end
  end

  defp read(file) do
    path = Application.app_dir(:blogo, "priv/repo/articles/#{file}")
    if File.exists?(path), do: Code.eval_file(path)
  end

  # Deleting the translations is what undoing this means. The originals keep
  # their group: it was theirs before any of this ran.
  def down do
    slugs = Enum.map(short_ones() ++ long_ones(), & &1.slug)

    repo().delete_all(from(p in "posts", where: p.slug in ^slugs))
  end

  defp insert(translation) do
    original =
      repo().one(
        from(p in "posts",
          where: p.slug == ^translation.of,
          select: %{
            id: p.id,
            group: p.translation_group,
            author_id: p.author_id,
            kind: p.kind,
            status: p.status,
            published_at: p.published_at,
            reading_minutes: p.reading_minutes
          }
        )
      )

    taken? =
      repo().exists?(from(p in "posts", where: p.slug == ^translation.slug))

    if original && not taken? do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      repo().insert_all("posts", [
        %{
          title: translation.title,
          subtitle: translation.subtitle,
          slug: translation.slug,
          kind: original.kind,
          status: original.status,
          published_at: original.published_at,
          reading_minutes: original.reading_minutes,
          topics: translation.topics,
          meta_description: translation.meta_description,
          language: translation.language,
          translation_group: original.group,
          body: %{"blocks" => translation.blocks},
          hero: translation.hero,
          lock_version: 1,
          author_id: original.author_id,
          inserted_at: now,
          updated_at: now
        }
      ])
    end
  end
end
