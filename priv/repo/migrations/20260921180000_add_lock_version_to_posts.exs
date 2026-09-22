defmodule Blogo.Repo.Migrations.AddLockVersionToPosts do
  use Ecto.Migration

  @moduledoc """
  Two tabs editing one post were last-write-wins in silence.

  Comparing `updated_at` almost works and is worse than nothing: the column has
  second precision, so the conflict it misses is exactly the fast one, and a
  guard that only catches slow conflicts gives false confidence. A counter the
  database checks on every write catches all of them.
  """

  def change do
    alter table(:posts) do
      add :lock_version, :integer, default: 1, null: false
    end
  end
end
