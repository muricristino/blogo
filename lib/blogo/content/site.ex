defmodule Blogo.Content.Site do
  @moduledoc """
  What this installation calls itself.

  Separate from the author on purpose: the site name goes in the header, the
  footer and `og:site_name`, while the author's name signs each article and
  owns the `Person` in the structured data. On a one-author blog they often
  match, and they are still two decisions.

  Nothing here has a default name. An unconfigured install falls back to its own
  hostname on the public side — a fact — and the panel says what to fill in.

  `featured_hero` is the one field that does have a default, because it is a
  choice about layout rather than an identity that has to be filled in: the
  featured card draws the article's diagram until someone says otherwise.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "site" do
    field :name, :string
    field :description, :string
    field :featured_hero, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(site, attrs) do
    site
    |> cast(attrs, [:name, :description, :featured_hero])
    |> update_change(:name, &blank_to_nil/1)
    |> update_change(:description, &blank_to_nil/1)
    |> validate_length(:name, max: 60)
    |> validate_length(:description, max: 160)
  end

  @doc "True when this install still has to be named."
  def unnamed?(%__MODULE__{name: name}), do: is_nil(name) or String.trim(name) == ""
  def unnamed?(_), do: true

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
