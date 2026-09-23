defmodule Blogo.Repo.Migrations.CreateReads do
  use Ecto.Migration

  @moduledoc """
  One row per article read.

  Everything the panel shows about an audience comes from this table, so what
  it does *not* hold is as deliberate as what it does: no visitor identifier,
  no cookie, no fingerprint, no IP. A read is a page view that reported back —
  it is not a person, and nothing here can tell whether a hundred reads are a
  hundred readers or one reader reloading.

  `day` is stored rather than derived from `inserted_at` because every query in
  the panel groups by it, and a date column can be indexed while
  `date_trunc(...)` on a timestamp cannot. It is UTC, the same convention
  `published_at` already uses.
  """

  def change do
    create table(:reads) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :day, :date, null: false

      # Where the reader came from, already classified: keeping the raw
      # referrer would be storing a URL someone else's page put in our hands,
      # for a question we only ever ask in five buckets.
      add :source, :string, null: false

      # Furthest point reached, 0–100, and how long the tab was actually
      # visible. Not how long it was open: a tab left in the background for an
      # hour is not an hour of reading.
      add :depth, :integer, null: false
      add :seconds, :integer, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:reads, [:post_id])
    create index(:reads, [:day])
  end
end
