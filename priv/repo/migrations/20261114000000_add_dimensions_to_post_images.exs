defmodule Blogo.Repo.Migrations.AddDimensionsToPostImages do
  use Ecto.Migration

  import Ecto.Query

  @moduledoc """
  The size each image declares, so the article can reserve its place before
  the lazy image arrives. Images stored before this are read from their own
  bytes here, once.
  """

  def up do
    alter table(:post_images) do
      add :width, :integer
      add :height, :integer
    end

    flush()

    from(i in "post_images", select: {i.id, i.data})
    |> repo().all()
    |> Enum.each(fn {id, data} ->
      case Blogo.Content.Photo.dimensions(data) do
        {w, h} ->
          repo().update_all(from(i in "post_images", where: i.id == ^id),
            set: [width: w, height: h]
          )

        nil ->
          :ok
      end
    end)
  end

  def down do
    alter table(:post_images) do
      remove :width
      remove :height
    end
  end
end
