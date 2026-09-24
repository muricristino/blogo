defmodule Blogo.Repo.Migrations.AddFeaturedHeroToSite do
  use Ecto.Migration

  @moduledoc """
  Whether the featured card on the home page draws the article's diagram.

  A large figure above the fold is an editorial choice, and blogo is installed
  by the person making it. It lives on `site` rather than on `posts` because the
  decision is about the home page, not about one article: per-article would let
  the same slot be a figure one week and text the next, which reads as a layout
  that is broken rather than one that was chosen.

  It defaults to true, so an existing install looks exactly as it did.
  """

  def change do
    alter table(:site) do
      add :featured_hero, :boolean, null: false, default: true
    end
  end
end
