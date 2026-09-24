defmodule Blogo.Analytics.Read do
  @moduledoc """
  One read of one article.

  The values arrive from a browser, so every one of them is clamped rather than
  trusted: a `depth` of 4000 or a `seconds` of 86400 would not be rejected by
  the panel, it would be averaged in and quietly ruin the figure it lands on.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # Twenty minutes of visible time on one article is already generous for an
  # eleven-minute essay. Past that, the number is measuring a forgotten tab.
  @max_seconds 20 * 60

  # "ia" is a reader sent by an assistant's answer. It is a source of its own
  # rather than a slice of "busca" because the two are different events: one was
  # picked from a list of results, the other was quoted into a reply.
  @sources ~w(busca redes newsletter interno direto ia outros)

  schema "reads" do
    field :day, :date
    field :source, :string
    field :depth, :integer
    field :seconds, :integer

    belongs_to :post, Blogo.Content.Post

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(read, attrs) do
    read
    |> cast(attrs, [:post_id, :day, :source, :depth, :seconds])
    |> validate_required([:post_id, :day, :source, :depth, :seconds])
    |> update_change(:depth, &clamp(&1, 0, 100))
    |> update_change(:seconds, &clamp(&1, 0, @max_seconds))
    |> validate_inclusion(:source, @sources)
    |> assoc_constraint(:post)
  end

  def sources, do: @sources
  def max_seconds, do: @max_seconds

  defp clamp(value, low, high) when is_integer(value),
    do: value |> max(low) |> min(high)

  defp clamp(_value, low, _high), do: low
end
