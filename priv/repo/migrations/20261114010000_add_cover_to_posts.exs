defmodule Blogo.Repo.Migrations.AddCoverToPosts do
  use Ecto.Migration

  @moduledoc """
  The photograph behind an article's header, named the way the post's own
  images are named. It is not the hero: the hero is the diagram that carries
  the conclusion and stays the figure on cards and in lists.
  """

  def change do
    alter table(:posts) do
      add :cover, :string
    end
  end
end
