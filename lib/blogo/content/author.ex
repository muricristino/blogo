defmodule Blogo.Content.Author do
  use Ecto.Schema
  import Ecto.Changeset

  schema "authors" do
    field :name, :string
    field :slug, :string
    field :headline, :string
    field :bio, :string
    field :avatar_url, :string
    field :city, :string
    field :same_as, {:array, :string}, default: []

    has_many :posts, Blogo.Content.Post

    timestamps(type: :utc_datetime)
  end

  def changeset(author, attrs) do
    author
    |> cast(attrs, [:name, :slug, :headline, :bio, :avatar_url, :city, :same_as])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
