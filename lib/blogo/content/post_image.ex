defmodule Blogo.Content.PostImage do
  @moduledoc """
  An image an article shows in its body.

  The bytes go through `Blogo.Content.Photo` on the way in, like the author's
  photo: a screenshot is harmless, a photo off a phone carries where it was
  taken, and this column is served publicly.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Blogo.Content.Photo

  @max_bytes 5_000_000

  @doc "The largest image accepted, in bytes."
  def max_bytes, do: @max_bytes

  schema "post_images" do
    field :name, :string
    field :content_type, :string
    field :digest, :string
    field :source_digest, :string
    field :byte_size, :integer
    field :data, :binary, load_in_query: false

    belongs_to :post, Blogo.Content.Post

    timestamps(type: :utc_datetime)
  end

  @name ~r/\A[A-Za-z0-9_][A-Za-z0-9._-]*(\/[A-Za-z0-9_][A-Za-z0-9._-]*)*\z/

  @doc """
  Whether a name may be stored. Segments may not start with a dot, so a name
  can never climb out of the folder `blogo get` writes it into.
  """
  def valid_name?(name) when is_binary(name),
    do: byte_size(name) <= 200 and Regex.match?(@name, name)

  def valid_name?(_), do: false

  @doc "A changeset storing `bytes` under `name` for `post_id`, cleaned."
  def changeset(image, post_id, name, bytes) when is_binary(bytes) do
    changeset =
      image
      |> change()
      |> force_change(:post_id, post_id)
      |> force_change(:name, name)

    cond do
      not valid_name?(name) ->
        add_error(changeset, :name, "deve ser um caminho relativo simples, como prints/tela.png")

      byte_size(bytes) > @max_bytes ->
        add_error(changeset, :data, "passa de #{div(@max_bytes, 1_000_000)} MB")

      true ->
        store(changeset, bytes, Photo.clean(bytes))
    end
  end

  defp store(changeset, source, {:ok, type, bytes}) do
    changeset
    |> force_change(:data, bytes)
    |> force_change(:content_type, type)
    |> force_change(:byte_size, byte_size(bytes))
    |> force_change(:digest, sha256(bytes))
    |> force_change(:source_digest, sha256(source))
  end

  defp store(changeset, _source, {:error, :unsupported}),
    do: add_error(changeset, :data, "precisa ser PNG, JPEG ou WebP")

  defp store(changeset, _source, {:error, :malformed}),
    do: add_error(changeset, :data, "está corrompida: não deu para ler a imagem inteira")

  @doc "The hex SHA-256 the CLI compares against."
  def sha256(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  @doc "Where the image is served: its digest, which makes the address immutable."
  def path(%__MODULE__{digest: digest, content_type: type}),
    do: "/midia/#{digest}.#{extension(type)}"

  @doc "The extension the served address carries, from the stored type."
  def extension("image/png"), do: "png"
  def extension("image/jpeg"), do: "jpg"
  def extension("image/webp"), do: "webp"
end
