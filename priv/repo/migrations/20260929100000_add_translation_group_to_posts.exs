defmodule Blogo.Repo.Migrations.AddTranslationGroupToPosts do
  @moduledoc """
  What ties an article to the same article in another language.

  A group rather than a pointer to "the original": with a pointer, the second
  translation has to decide whether it points at the first or at the source, and
  deleting the source orphans the rest. A group is symmetric and survives both.

  Every existing post gets a group of its own — each is, correctly, the only
  version of itself so far.
  """
  use Ecto.Migration

  def up do
    execute "create extension if not exists pgcrypto"

    # The default is the point: a post nobody translated is the only member of
    # its own group, and that has to happen without any code path remembering
    # to make it happen.
    alter table(:posts) do
      add :translation_group, :uuid, null: false, default: fragment("gen_random_uuid()")
    end

    create index(:posts, [:translation_group])

    # Two articles in the same language in one group would be two answers to
    # "which one does this reader get", and nothing downstream could choose.
    create unique_index(:posts, [:translation_group, :language])
  end

  def down do
    drop index(:posts, [:translation_group, :language])
    drop index(:posts, [:translation_group])

    alter table(:posts) do
      remove :translation_group
    end
  end
end
