defmodule Blogo.Repo.Migrations.AddAiCrawlersToSite do
  use Ecto.Migration

  @moduledoc """
  What this install decided about crawlers that feed a generative model.

  Nullable on purpose: "nobody has decided yet" is a real state the panel has to
  be able to say out loud. A default written into the column would look like a
  choice somebody made, which is the opposite of what the feature is for.
  """

  def change do
    alter table(:site) do
      add :ai_crawlers, :string
    end
  end
end
