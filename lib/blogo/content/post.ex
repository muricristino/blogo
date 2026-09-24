defmodule Blogo.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset

  # "pagina" is a fixed page — Sobre, Contato — written in the editor like any
  # article but kept out of the index, the feed and the topic pages. It is a
  # kind rather than a flag because an article is already one of several kinds,
  # and a second axis saying "but not really an article" would be one more
  # thing to remember at every query.
  @kinds ~w(ensaio nota pagina)
  @statuses ~w(draft scheduled published)

  @doc "The kinds a post may be, in the order the editor offers them."
  def kinds, do: @kinds

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

    # Series left the interface but the data stays: the table, these columns and
    # what was already declared in them. Recreating content is expensive and
    # dropping a table is cheap, so nothing here is a leftover to clean up.
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
      :author_id
    ])
    |> optimistic_lock(:lock_version)
    |> validate_required([:title, :slug, :author_id])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:slug)
    |> assoc_constraint(:author)
    |> validate_hero()
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
