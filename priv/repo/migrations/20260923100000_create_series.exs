defmodule Blogo.Repo.Migrations.CreateSeries do
  use Ecto.Migration

  @moduledoc """
  Series used to be three maps written by hand in `PostController`, rendered on
  the index as though they were real, with a "2 de 4 lidos" nobody had measured.
  """

  def change do
    create table(:series) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:series, [:slug])

    alter table(:posts) do
      add :series_id, references(:series, on_delete: :nilify_all)
      add :series_position, :integer
    end

    # A series is read in order, so position has to be unique within one —
    # two articles both claiming to be part 2 is a bug the reader sees.
    create unique_index(:posts, [:series_id, :series_position],
             where: "series_id IS NOT NULL",
             name: :posts_series_position_index
           )
  end
end
