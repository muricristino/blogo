defmodule Blogo.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string, null: false
      add :subtitle, :text
      add :slug, :string, null: false
      add :kind, :string, null: false, default: "ensaio"
      add :status, :string, null: false, default: "draft"
      add :published_at, :utc_datetime
      add :reading_minutes, :integer
      add :topics, {:array, :string}, null: false, default: []
      add :body, :map, null: false, default: %{}
      add :meta_description, :string
      add :author_id, references(:authors, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:author_id])
    create index(:posts, [:status, :published_at])
  end
end
