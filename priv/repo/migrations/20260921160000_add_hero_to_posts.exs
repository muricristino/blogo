defmodule Blogo.Repo.Migrations.AddHeroToPosts do
  use Ecto.Migration

  def change do
    # The article's own key diagram, reused as the card figure and the list
    # thumbnail. Stored as a block so it renders through the same components
    # as the ones in the body — there is no second drawing to keep in sync.
    alter table(:posts) do
      add :hero, :map
    end
  end
end
