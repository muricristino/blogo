defmodule Blogo.Repo.Migrations.AddAuthorPhoto do
  use Ecto.Migration

  @moduledoc """
  The author's photo, stored in the database.

  Where the bytes live is the whole decision here. The application runs in a
  container that webo replaces on every deploy, and neither compose file
  declares a volume for it — so a file written under `priv/static/uploads` or
  `/tmp` is gone the next time the image is built, and the avatar would vanish
  on a deploy nobody connected to it. Postgres runs in its own container with
  its own data, which is what actually survives, so the photo lives beside the
  author it belongs to and the application serves it from there.

  `avatar_url` stays where it is, unused. Dropping a column is a destructive
  migration that runs at boot in production, and this is not the change to do
  it in.
  """

  def change do
    alter table(:authors) do
      add :photo, :binary
      add :photo_type, :string
      add :photo_digest, :string
    end
  end
end
