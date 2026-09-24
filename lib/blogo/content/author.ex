defmodule Blogo.Content.Author do
  @moduledoc """
  Who signs the blog.

  The photo is stored here, as bytes, because the application runs in a
  container with no volume: a file written to disk lives until the next deploy
  and then is not there any more, with nothing on screen to say why. The
  database is the only part of this deployment that survives a rebuild.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Blogo.Content.Photo

  # 64px on screen, twice that on a retina display. Anything past this is
  # bandwidth spent on every visit to show a face 128 pixels wide.
  @max_photo_bytes 2_000_000

  @doc "The largest photo accepted, in bytes. The panel shows the same limit."
  def max_photo_bytes, do: @max_photo_bytes

  schema "authors" do
    field :name, :string
    field :slug, :string
    field :headline, :string
    field :bio, :string
    field :avatar_url, :string
    field :city, :string
    field :same_as, {:array, :string}, default: []

    field :photo_type, :string
    field :photo_digest, :string
    # Every post query preloads its author, so the bytes would ride along into
    # the index, the article, the feed and the card — megabytes fetched to
    # render a page that never shows them. They are read by the one request
    # that serves the image.
    field :photo, :binary, load_in_query: false

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

  @doc "Whether there is a photo to show, without fetching the bytes to find out."
  def photo?(%__MODULE__{photo_digest: digest}), do: is_binary(digest)
  def photo?(_), do: false

  @doc """
  The uploaded photo, stripped of everything that is not the picture.

  The format is read from the first bytes rather than taken from the name or
  the content type the browser sent: both are typed by whoever uploads, and a
  `.png` that is not a PNG renders as a broken image on every article.

  What reaches the column is what `Blogo.Content.Photo` gives back, never the
  file as it arrived — the photo is served publicly, and a photo off a phone
  carries the GPS coordinates of where it was taken. The digest is taken from
  the cleaned bytes, because it is the cache key for what will be served.

  Every write here is a `force_change/3`, and that is load-bearing. `change/2`
  compares against the data and drops whatever looks unchanged, and `:photo` is
  never loaded — so the struct always reports nil, and the delete built on
  `change/2` wrote nothing at all: the bytes stayed in the row with their type
  and digest cleared, invisible to the site and still on disk. It is the defect
  CLAUDE.md records for the editor, reached from the other direction.
  """
  def photo_changeset(author, bytes) when is_binary(bytes) do
    changeset = change(author)

    if byte_size(bytes) > @max_photo_bytes do
      add_error(changeset, :photo, "passa de #{div(@max_photo_bytes, 1_000_000)} MB")
    else
      store(changeset, Photo.clean(bytes))
    end
  end

  defp store(changeset, {:ok, type, bytes}) do
    changeset
    |> force_change(:photo, bytes)
    |> force_change(:photo_type, type)
    |> force_change(:photo_digest, Base.encode16(:crypto.hash(:sha256, bytes), case: :lower))
  end

  defp store(changeset, {:error, :unsupported}),
    do: add_error(changeset, :photo, "precisa ser PNG, JPEG ou WebP")

  # A file that cannot be taken apart cannot be stripped of its metadata, and
  # storing it as it came is exactly what this refuses to do.
  defp store(changeset, {:error, :malformed}),
    do: add_error(changeset, :photo, "está corrompida: não deu para ler a imagem inteira")

  @doc "Takes the photo off, leaving the initials in its place."
  def no_photo_changeset(author) do
    author
    |> change()
    |> force_change(:photo, nil)
    |> force_change(:photo_type, nil)
    |> force_change(:photo_digest, nil)
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
