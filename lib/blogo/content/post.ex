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

    # Stored whole so a design change re-renders every post rather than needing
    # a content migration.
    field :body, :map, default: %{}

    # The article's key diagram, shaped like a diagram block: card figure and
    # list thumbnail.
    field :hero, :map

    # Checked by the database: two tabs used to overwrite each other silently.
    field :lock_version, :integer, default: 1

    belongs_to :author, Blogo.Content.Author

    # An article belongs to at most one series and knows where it sits in it.
    belongs_to :series, Blogo.Content.Series
    field :series_position, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title,
      :subtitle,
      :slug,
      :kind,
      :status,
      :published_at,
      :reading_minutes,
      :topics,
      :meta_description,
      :body,
      :hero,
      :author_id,
      :series_id,
      :series_position
    ])
    |> optimistic_lock(:lock_version)
    |> validate_required([:title, :slug, :author_id])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:slug)
    |> unique_constraint(:series_position,
      name: :posts_series_position_index,
      message: "já é ocupada por outro artigo desta série"
    )
    |> assoc_constraint(:author)
    |> validate_hero()
    |> validate_series()
  end

  # A position without a series is a number that means nothing, and a series
  # without a position has no place in the reading order.
  defp validate_series(changeset) do
    case {get_field(changeset, :series_id), get_field(changeset, :series_position)} do
      {nil, nil} -> changeset
      {nil, _} -> add_error(changeset, :series_position, "precisa de uma série")
      {_, nil} -> add_error(changeset, :series_position, "é obrigatória quando há série")
      {_, n} when n < 1 -> add_error(changeset, :series_position, "começa em 1")
      _ -> changeset
    end
  end

  # Enforced at publication, not creation: a draft may be incomplete. See
  # CLAUDE.md.
  defp validate_hero(changeset) do
    case get_field(changeset, :status) do
      "published" ->
        case get_field(changeset, :hero) do
          %{"form" => form} when is_binary(form) ->
            changeset

          _ ->
            add_error(
              changeset,
              :hero,
              "é obrigatório: escolha uma forma no painel Diagrama de capa"
            )
        end

      _ ->
        changeset
    end
  end

  def blocks(%__MODULE__{body: %{"blocks" => blocks}}) when is_list(blocks), do: blocks
  def blocks(_), do: []

  def hero?(%__MODULE__{hero: %{"form" => f}}) when is_binary(f), do: true
  def hero?(_), do: false

  @doc """
  The blocks as the article page shows them: the key-numbers block lifted out
  to become the summary, and sections numbered.

  It lives here rather than in the controller because the preview renders the
  same article and must not drift from it — two copies of this would mean a
  draft that looks right in preview and wrong once published.
  """
  def for_reading(post) do
    blocks = blocks(post)
    {summary, blocks} = pop_summary(blocks)
    {summary, number_sections(blocks)}
  end

  defp pop_summary(blocks) do
    case Enum.split_while(blocks, &(&1["type"] != "keynumbers")) do
      {before, [summary | rest]} -> {summary, before ++ rest}
      {all, []} -> {nil, all}
    end
  end

  # Derived, not authored: renaming a section should not mean renumbering the
  # table of contents by hand.
  defp number_sections(blocks) do
    {blocks, _} =
      Enum.map_reduce(blocks, 0, fn
        %{"type" => "section"} = b, n ->
          n = n + 1
          {Map.merge(b, %{"n" => String.pad_leading("#{n}", 2, "0"), "id" => "sec-#{n}"}), n}

        b, n ->
          {b, n}
      end)

    blocks
  end
end
