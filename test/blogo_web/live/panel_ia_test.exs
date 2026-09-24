defmodule BlogoWeb.PanelIaTest do
  @moduledoc """
  The panel gained an "AI answer" origin. The split did not exist before the
  migration ran, so the screen has to say since when it does — otherwise an
  older window shows a small slice and reads as a measurement.
  """
  use BlogoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Blogo.{Analytics, Fixtures}
  alias Blogo.Content.Site

  @password "senha-de-teste"

  setup do
    Application.put_env(:blogo, :admin_password, @password)
    on_exit(fn -> Application.delete_env(:blogo, :admin_password) end)
    :ok
  end

  defp sign_in(conn) do
    conn
    |> Phoenix.ConnTest.post(~p"/auth/login", %{"password" => @password})
    |> Phoenix.ConnTest.recycle()
  end

  describe "the AI answer origin" do
    setup %{conn: conn} do
      post = Fixtures.post(%{status: "published", title: "Artigo medido"})
      %{conn: sign_in(conn), post: post}
    end

    defp read(post, attrs) do
      {:ok, _} =
        Analytics.record_read(
          post.id,
          Map.merge(%{depth: 50, seconds: 60, source: "direto", day: Date.utc_today()}, attrs)
        )
    end

    test "is charted under a name somebody can read", %{conn: conn, post: post} do
      read(post, %{source: "ia"})

      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "resposta de IA"
    end

    # The split did not exist before the migration ran, so reads from before it
    # are filed as search or other. A small slice with no explanation is a
    # measurement the panel would be inventing.
    test "says since when the split exists, when there are older reads", %{conn: conn, post: post} do
      ontem = Date.add(Date.utc_today(), -1)
      Blogo.Repo.insert!(%Site{id: 1, ai_referrals_since: Date.utc_today()})
      read(post, %{source: "busca", day: ontem})
      read(post, %{source: "ia"})

      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "só passou a ser separada em"
    end

    test "keeps quiet when every read already knew the difference", %{conn: conn, post: post} do
      Blogo.Repo.insert!(%Site{id: 1, ai_referrals_since: Date.add(Date.utc_today(), -10)})
      read(post, %{source: "ia"})

      {:ok, _live, html} = live(conn, ~p"/painel")

      refute html =~ "só passou a ser separada em"
    end

    test "keeps quiet on a fresh install, which has no boundary to declare", %{
      conn: conn,
      post: post
    } do
      read(post, %{source: "ia"})

      {:ok, _live, html} = live(conn, ~p"/painel")

      refute html =~ "só passou a ser separada em"
    end
  end
end
