defmodule Blogo.Repo.Migrations.AddLanguageToPosts do
  use Ecto.Migration

  @moduledoc """
  The language a post is written in.

  The interface can now answer in English, and the article cannot: translating
  the menu is a string table, translating an article is writing another
  article. So the post has to say which language its own words are in, because
  that is what `<html lang>` and `inLanguage` have to declare. Reading it off
  the reader's menu would tell a search engine that a Portuguese essay is
  English, which is worse than saying nothing.

  Default `pt-BR`, which is true of everything written here so far — a BCP 47
  tag, because every consumer of this column is markup.
  """

  def change do
    alter table(:posts) do
      add :language, :string, null: false, default: "pt-BR"
    end
  end
end
