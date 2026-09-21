defmodule Blogo.Repo.Migrations.CreateAuthors do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :headline, :string
      add :bio, :text
      add :avatar_url, :string
      add :city, :string
      # schema.org sameAs — the profiles that tie this name to one entity
      add :same_as, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:authors, [:slug])
  end
end
