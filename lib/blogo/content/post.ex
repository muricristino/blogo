defmodule Blogo.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(ensaio nota)
  @statuses ~w(draft scheduled published)

  schema "posts" do
    field :title, :string
    field :subtitle, :string
    field :slug, :string
    field :kind, :string, default: "ensaio"
    field :status, :string, default: "draft"
    field :published_at, :utc_datetime
    field :reading_minutes, :integer
    field :topics, {:array, :string}, default: []
    field :meta_description, :string

    # The block list the editor produces. Stored whole so a design change
    # re-renders every post instead of requiring a content migration.
    field :body, :map, default: %{}

    belongs_to :author, Blogo.Content.Author

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title, :subtitle, :slug, :kind, :status, :published_at,
      :reading_minutes, :topics, :meta_description, :body, :author_id
    ])
    |> validate_required([:title, :slug, :author_id])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:slug)
    |> assoc_constraint(:author)
  end

  def blocks(%__MODULE__{body: %{"blocks" => blocks}}) when is_list(blocks), do: blocks
  def blocks(_), do: []
end
