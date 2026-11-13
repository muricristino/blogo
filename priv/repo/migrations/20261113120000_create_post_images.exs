defmodule Blogo.Repo.Migrations.CreatePostImages do
  use Ecto.Migration

  @moduledoc """
  Images inside an article, stored in the database for the same reason as the
  author's photo: the application container is replaced on every deploy and
  mounts no volume, and Postgres is what survives.

  An image belongs to one post and is named the way the markdown names it, so
  the text and the stored file can be matched without a third identifier.
  `source_digest` is the hash of the file as it was uploaded — what the CLI can
  compute locally — while `digest` is the hash of the cleaned bytes, which is
  what is served and what the address is built from.
  """

  def change do
    create table(:post_images) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :content_type, :string, null: false
      add :digest, :string, null: false
      add :source_digest, :string, null: false
      add :byte_size, :integer, null: false
      add :data, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:post_images, [:post_id, :name])
    create index(:post_images, [:digest])
  end
end
