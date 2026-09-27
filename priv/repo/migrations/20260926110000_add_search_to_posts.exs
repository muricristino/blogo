defmodule Blogo.Repo.Migrations.AddSearchToPosts do
  @moduledoc """
  What a search reads. A generated column rather than something the application
  keeps in step: there is no code path that can write a post and forget to
  update it, which is the way a search index goes quietly stale.

  The body is JSONB, so the text lives inside it — `jsonb_to_tsvector` with
  `["string"]` pulls every string out, which is every paragraph, heading,
  caption and table cell, without this needing to know the block vocabulary.

  Indexed under **two** dictionaries. A single one would have to be the site's
  language, and the blog is about to hold articles in more than one; stemming a
  Portuguese article as English finds nothing. Two vectors concatenated costs a
  bigger index on a table with single-digit thousands of rows, which is nothing,
  and means a search in either language works from the day it is written.
  """
  use Ecto.Migration

  def up do
    execute """
    alter table posts add column search tsvector
      generated always as (
        setweight(to_tsvector('portuguese', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english',    coalesce(title, '')), 'A') ||
        setweight(to_tsvector('portuguese', coalesce(subtitle, '')), 'B') ||
        setweight(to_tsvector('english',    coalesce(subtitle, '')), 'B') ||
        setweight(array_to_tsvector(coalesce(topics, '{}')), 'B') ||
        setweight(jsonb_to_tsvector('portuguese', coalesce(body, '{}'::jsonb), '["string"]'), 'C') ||
        setweight(jsonb_to_tsvector('english',    coalesce(body, '{}'::jsonb), '["string"]'), 'C')
      ) stored
    """

    execute "create index posts_search_idx on posts using gin (search)"
  end

  def down do
    execute "drop index if exists posts_search_idx"
    execute "alter table posts drop column if exists search"
  end
end
