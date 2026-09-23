defmodule Blogo.Repo.Migrations.FixAuthorSameAs do
  use Ecto.Migration

  @moduledoc """
  `sameAs` was pointing at github.com/murichristopher, which is not this
  author's account.

  That field is the whole mechanism behind the goal this blog exists for: it
  tells a search engine that the articles, the author page and the linked
  profiles are one person. Pointing it at somebody else's account does not
  merely fail to help — it hands the association away.

  Seeds only run on an empty database, so the row already in production needed
  this.
  """

  def up do
    execute("""
    UPDATE authors
       SET same_as = array_replace(
             same_as,
             'https://github.com/murichristopher',
             'https://github.com/muricristino'
           )
     WHERE 'https://github.com/murichristopher' = ANY(same_as)
    """)
  end

  def down, do: :ok
end
