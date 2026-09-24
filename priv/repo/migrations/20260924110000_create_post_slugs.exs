defmodule Blogo.Repo.Migrations.CreatePostSlugs do
  use Ecto.Migration

  @moduledoc """
  The editor lets someone change an article's address in two clicks, and until
  now the old address became a 404. On a blog that lives on being linked, that
  throws away exactly what took longest to earn.

  Every address an article has ever had is kept, so the old one can answer 301.
  """

  def change do
    create table(:post_slugs) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # One address points at one article. Reusing an address that already
    # redirects elsewhere would make the redirect lie.
    create unique_index(:post_slugs, [:slug])
    create index(:post_slugs, [:post_id])
  end
end
