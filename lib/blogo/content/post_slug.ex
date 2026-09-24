defmodule Blogo.Content.PostSlug do
  @moduledoc """
  An address an article used to have, kept so it can answer 301 instead of 404.
  """
  use Ecto.Schema

  schema "post_slugs" do
    field :slug, :string
    belongs_to :post, Blogo.Content.Post

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
