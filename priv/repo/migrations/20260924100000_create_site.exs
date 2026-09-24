defmodule Blogo.Repo.Migrations.CreateSite do
  use Ecto.Migration

  @moduledoc """
  blogo is self-hosted, and whoever installs it does not want a site called
  "blogo". The name was written into the header, the footer, the page title and
  `og:site_name`.

  One row, not a key-value table: the fields are few and known, and a schema
  gives them types and a changeset — the same shape the panel already edits for
  the author. A key-value store would put validation nowhere.
  """

  def change do
    create table(:site) do
      add :name, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    # There is one site. Without this, a second row is a silent fork of the
    # configuration where half the pages read one name and half the other.
    create constraint(:site, :site_is_a_single_row, check: "id = 1")
  end
end
