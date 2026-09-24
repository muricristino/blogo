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
    |> clean_same_as()
    |> validate_same_as()
  end

  @doc """
  The changeset the panel uses. The slug is absent on purpose: it is inside the
  schema.org `@id` that every article points at, so changing it tells a search
  engine this is a different person and resets the association the whole blog
  exists to build.
  """
  def profile_changeset(author, attrs) do
    author
    |> cast(attrs, [:name, :headline, :bio, :city, :same_as])
    |> validate_required([:name])
    |> clean_same_as()
    |> validate_same_as()
  end

  # A blank line in the form is someone who pressed enter, not a profile.
  defp clean_same_as(changeset) do
    case get_change(changeset, :same_as) do
      nil ->
        changeset

      list ->
        put_change(
          changeset,
          :same_as,
          list |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        )
    end
  end

  # `sameAs` is what proves the profiles belong to the same person. An entry
  # that is not a URL proves nothing and is quietly ignored by search engines,
  # so it is refused here where someone can still fix it.
  defp validate_same_as(changeset) do
    case get_change(changeset, :same_as) do
      nil ->
        changeset

      list ->
        case Enum.reject(list, &url?/1) do
          [] -> changeset
          [bad | _] -> add_error(changeset, :same_as, "não é um endereço válido: #{bad}")
        end
    end
  end

  defp url?(value) do
    case URI.parse(value) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] ->
        is_binary(host) and String.contains?(host, ".")

      _ ->
        false
    end
  end
end
