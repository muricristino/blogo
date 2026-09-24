defmodule Blogo.Repo.Migrations.AddAiReferralsSinceToSite do
  use Ecto.Migration

  @moduledoc """
  The day the panel started telling an AI answer apart from a search result.

  This is not configuration, it is a measurement boundary. Reads collected
  before this migration ran were classified without the split and sit in
  `busca` or `outros`, so a window reaching further back shows an AI share
  smaller than it was. Without the date there is nothing on screen to say so,
  and the panel would be presenting a gap in the rules as a fact about readers.
  """

  def up do
    alter table(:site) do
      add :ai_referrals_since, :date
    end

    # Only an install that was already measuring has reads it cannot classify;
    # a fresh one has no boundary to declare.
    execute """
    INSERT INTO site (id, ai_referrals_since, inserted_at, updated_at)
    SELECT 1, CURRENT_DATE, now(), now()
    WHERE EXISTS (SELECT 1 FROM reads)
    ON CONFLICT (id) DO UPDATE SET ai_referrals_since = CURRENT_DATE
    """
  end

  def down do
    alter table(:site) do
      remove :ai_referrals_since
    end
  end
end
