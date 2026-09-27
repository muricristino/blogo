defmodule Blogo.Repo.Migrations.RenameEnsaioToArtigo do
  @moduledoc """
  The kind an article has was called `ensaio`, and the line above the title said
  so. It says `artigo` now, and the column follows the screen — a label that
  disagrees with the value is a thing the editor shows in its palette and the
  next person finds in the schema.
  """
  use Ecto.Migration

  def up do
    execute "update posts set kind = 'artigo' where kind = 'ensaio'"
  end

  def down do
    execute "update posts set kind = 'ensaio' where kind = 'artigo'"
  end
end
