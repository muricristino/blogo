defmodule Blogo.Content.SeriesTest do
  @moduledoc """
  A series is a reading order the author declares. What these protect is that
  the order is real and that nothing on screen can claim more parts than are
  actually published.
  """
  use Blogo.DataCase

  alias Blogo.{Content, Fixtures}

  defp series(attrs \\ %{}) do
    {:ok, series} =
      Content.upsert_series(
        Map.merge(
          %{
            name: "Avaliar sem se enganar",
            slug: "avaliar-#{System.unique_integer([:positive])}",
            description: "Do conjunto de teste ao limiar."
          },
          attrs
        )
      )

    series
  end

  describe "reading order" do
    test "parts come back in position order, not publication order" do
      s = series()
      author = Fixtures.author()

      # Published newest-first, so any ordering by date would reverse these.
      Fixtures.post(%{
        author: author,
        series_id: s.id,
        series_position: 2,
        title: "Segundo",
        published_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      Fixtures.post(%{
        author: author,
        series_id: s.id,
        series_position: 1,
        title: "Primeiro",
        published_at: DateTime.utc_now() |> DateTime.add(-86_400) |> DateTime.truncate(:second)
      })

      assert ["Primeiro", "Segundo"] =
               Content.get_series_by_slug(s.slug).posts |> Enum.map(& &1.title)
    end

    test "a draft is not a part, because the reader cannot open it" do
      s = series()
      Fixtures.post(%{series_id: s.id, series_position: 1})
      Fixtures.post(%{series_id: s.id, series_position: 2, status: "draft", hero: nil})

      assert [_only_one] = Content.get_series_by_slug(s.slug).posts
    end

    # A series with nothing published is a promise of nothing.
    test "a series with no published part is not listed" do
      s = series()
      Fixtures.post(%{series_id: s.id, series_position: 1, status: "draft", hero: nil})

      refute Enum.any?(Content.list_series(), &(&1.id == s.id))
    end

    test "series with parts are listed" do
      s = series()
      Fixtures.post(%{series_id: s.id, series_position: 1})

      assert Enum.any?(Content.list_series(), &(&1.id == s.id))
    end
  end

  describe "what a post may claim" do
    test "a position without a series is refused" do
      author = Fixtures.author()

      assert {:error, changeset} =
               Content.create_post(%{
                 title: "Sem série",
                 slug: "sem-serie-#{System.unique_integer([:positive])}",
                 author_id: author.id,
                 series_position: 2
               })

      assert %{series_position: ["precisa de uma série"]} = errors_on(changeset)
    end

    test "a series without a position is refused" do
      s = series()
      author = Fixtures.author()

      assert {:error, changeset} =
               Content.create_post(%{
                 title: "Sem posição",
                 slug: "sem-posicao-#{System.unique_integer([:positive])}",
                 author_id: author.id,
                 series_id: s.id
               })

      assert %{series_position: ["é obrigatória quando há série"]} = errors_on(changeset)
    end

    # Two articles both saying "part 2" is a contradiction the reader sees.
    test "two articles cannot hold the same position" do
      s = series()
      Fixtures.post(%{series_id: s.id, series_position: 1})
      author = Fixtures.author()

      assert {:error, changeset} =
               Content.create_post(%{
                 title: "Outro primeiro",
                 slug: "outro-primeiro-#{System.unique_integer([:positive])}",
                 author_id: author.id,
                 series_id: s.id,
                 series_position: 1
               })

      assert %{series_position: [_]} = errors_on(changeset)
    end

    test "an article with no series at all is fine" do
      assert %{series_id: nil} = Fixtures.post()
    end
  end

  describe "the editor" do
    test "assigning a series reaches the database" do
      s = series()
      post = Fixtures.post()

      {:ok, _} = Content.save_post(post, %{series_id: s.id, series_position: 1})

      saved = Content.get_post!(post.id)
      assert saved.series_id == s.id
      assert saved.series_position == 1
    end

    test "clearing the series clears the position with it" do
      s = series()
      post = Fixtures.post(%{series_id: s.id, series_position: 1})

      {:ok, _} = Content.save_post(post, %{series_id: nil, series_position: nil})

      saved = Content.get_post!(post.id)
      assert is_nil(saved.series_id)
      assert is_nil(saved.series_position)
    end
  end
end
