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
          author_id: a.id
        }
        |> Map.merge(Map.drop(attrs, [:author]))
      )

    %{post | author: a}
  end
end
