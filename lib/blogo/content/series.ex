defmodule Blogo.Content.Series do
  @moduledoc """
  A reading order the author declares: a name, a short description and the
  articles in the sequence they were meant to be read.

  There is no notion of progress here. A read is an anonymous page view — no
  cookie, no identifier — so nothing in this system can say whether one person
  read two parts or two people read one each. The index used to show "2 de 4
  lidos" anyway.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "series" do
    field :name, :string
    field :slug, :string
    field :description, :string

    has_many :posts, Blogo.Content.Post

    timestamps(type: :utc_datetime)
  end

  def changeset(series, attrs) do
    series
    |> cast(attrs, [:name, :slug, :description])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
