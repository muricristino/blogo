defmodule Blogo.Fixtures do
  @moduledoc "Minimal records for tests: one author, one published post."

  alias Blogo.Content

  def author(attrs \\ %{}) do
    {:ok, author} =
      Content.create_author(
        Map.merge(
          %{
            name: "Muri Cristino",
            slug: "muri-cristino-#{System.unique_integer([:positive])}",
            headline: "Engenheiro de software",
            bio: "Escrevo sobre o que eu meço.",
            same_as: ["https://github.com/muricristino"]
          },
          attrs
        )
      )

    author
  end

  @doc """
  Bytes that a real image starts with.

  The application reads the format from the first bytes rather than from the
  name or the content type the browser claims, so a header plus filler is
  exactly what it inspects. Nothing here decodes the image, and a fixture that
  needed a real encoder would test the encoder.
  """
  def png(size \\ 96), do: <<0x89, "PNG\r\n", 0x1A, 0x0A>> <> filler(size - 8)
  def jpeg(size \\ 96), do: <<0xFF, 0xD8, 0xFF, 0xE0>> <> filler(size - 4)

  def webp(size \\ 96),
    do: "RIFF" <> <<size - 8::little-32>> <> "WEBP" <> filler(size - 12)

  defp filler(n) when n > 0, do: :binary.copy(<<0>>, n)
  defp filler(_), do: ""

  def post(attrs \\ %{}) do
    a = attrs[:author] || author()

    {:ok, post} =
      Content.create_post(
        %{
          title: "Um título",
          subtitle: "Uma linha de apoio.",
          slug: "um-titulo-#{System.unique_integer([:positive])}",
          status: "published",
          published_at: DateTime.utc_now() |> DateTime.truncate(:second),
          reading_minutes: 7,
          topics: ["avaliação"],
          meta_description: "Descrição para busca.",
          body: %{"blocks" => [%{"type" => "text", "paragraphs" => ["Olá."]}]},
          hero: %{"form" => "fluxo", "data" => %{"steps" => []}, "alt" => "Um fluxo"},
          author_id: a.id
        }
        |> Map.merge(Map.drop(attrs, [:author]))
      )

    %{post | author: a}
  end
end
