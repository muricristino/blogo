defmodule Blogo.Repo.Migrations.BackfillFirstSeries do
  use Ecto.Migration

  @moduledoc """
  The index used to show three invented series; production has the articles
  that make one of them real. Seeds only run on an empty database, so without
  this the section would simply disappear there.

  Literal SQL rather than the schema: a data migration that goes through
  `Blogo.Content` breaks the day the context changes, months after this ran.
  """

  @slug "avaliar-sem-se-enganar"

  # Reading order, not publication order: build the test set, measure with it,
  # then compare two models properly.
  @parts [{"conjunto-de-180-casos", 1}, {"laya-x-jev", 2}, {"mcnemar-em-ruby", 3}]

  def up do
    execute("""
    INSERT INTO series (name, slug, description, inserted_at, updated_at)
    SELECT 'Avaliar sem se enganar',
           '#{@slug}',
           'Do conjunto de teste ao limiar calibrado: como montar os casos, o que medir neles e como comparar dois modelos sem se convencer do resultado que você queria.',
           now(), now()
     WHERE NOT EXISTS (SELECT 1 FROM series WHERE slug = '#{@slug}')
    """)

    for {slug, position} <- @parts do
      execute("""
      UPDATE posts
         SET series_id = (SELECT id FROM series WHERE slug = '#{@slug}'),
             series_position = #{position}
       WHERE slug = '#{slug}' AND series_id IS NULL
      """)
    end
  end

  # The column goes with the migration that added it; there is nothing here to
  # restore.
  def down, do: :ok
end
