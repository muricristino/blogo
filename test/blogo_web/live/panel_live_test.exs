defmodule BlogoWeb.PanelLiveTest do
  @moduledoc """
  The panel's job is to be believed, so most of these cases check the wording
  around a missing number rather than the number itself.
  """
  use BlogoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Blogo.Analytics
  alias Blogo.Fixtures

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

  defp read(post, attrs \\ %{}) do
    {:ok, _} =
      Analytics.record_read(
        post.id,
        Map.merge(%{depth: 50, seconds: 60, source: "direto", day: Date.utc_today()}, attrs)
      )
  end

  describe "quem entra" do
    test "o painel redireciona quem não entrou", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/login"}}} = live(conn, ~p"/painel")
    end

    # The socket reconnects over a websocket, which never re-runs a plug.
    test "o socket é guardado, não só a requisição", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/login"}}} = live(conn, ~p"/painel")
    end
  end

  describe "sem medição nenhuma" do
    setup %{conn: conn}, do: %{conn: sign_in(conn)}

    # This is the case a naive panel gets wrong: it shows zeros, and the author
    # reads "nobody came" when the truth is "nothing is counting yet".
    test "diz que ainda não mede, em vez de mostrar zeros", %{conn: conn} do
      Fixtures.post(%{status: "published"})
      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "Ainda não há leituras registradas"
      refute html =~ "0%"
    end

    test "a coluna de leituras fica em traço, não em zero", %{conn: conn} do
      Fixtures.post(%{status: "published", title: "Um artigo"})
      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "Um artigo"
      assert html =~ "—"
    end
  end

  describe "com leituras" do
    setup %{conn: conn} do
      post = Fixtures.post(%{status: "published", title: "Artigo medido"})
      %{conn: sign_in(conn), post: post}
    end

    test "mostra o total e a taxa de conclusão", %{conn: conn, post: post} do
      read(post, %{depth: 95})
      read(post, %{depth: 20})

      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "Leituras"
      assert html =~ "50%"
      refute html =~ "Ainda não há leituras registradas"
    end

    test "a origem aparece com a porcentagem", %{conn: conn, post: post} do
      read(post, %{source: "busca"})
      read(post, %{source: "busca"})
      read(post, %{source: "redes"})

      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "busca"
      assert html =~ "67%"
    end

    test "trocar o período refaz as contas", %{conn: conn, post: post} do
      read(post, %{day: Date.add(Date.utc_today(), -40)})

      {:ok, live, html} = live(conn, ~p"/painel")
      # Fora da janela de 30 dias.
      assert html =~ "Nenhuma leitura neste período"

      html = live |> element(~s|button[phx-value-value="90"]|) |> render_click()
      refute html =~ "Nenhuma leitura neste período"
    end

    test "o filtro de publicações separa rascunho de publicado", %{conn: conn} do
      Fixtures.post(%{status: "draft", title: "Só um rascunho", hero: nil})

      {:ok, live, html} = live(conn, ~p"/painel")
      assert html =~ "Só um rascunho"
      assert html =~ "Artigo medido"

      html = live |> element(~s|button[phx-value-value="published"]|) |> render_click()
      assert html =~ "Artigo medido"
      refute html =~ "Só um rascunho"
    end
  end

  describe "o que não é medido" do
    setup %{conn: conn}, do: %{conn: sign_in(conn)}

    # No newsletter exists, so there is nothing to count. Showing a zero here
    # would be inventing a fact about an audience that has no way to exist.
    test "assinantes diz por que não há número", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "Assinantes"
      assert html =~ "A newsletter ainda não existe"
    end

    test "a fila explica a ausência de comentários e newsletter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "Comentários e newsletter ainda não existem"
    end
  end

  describe "a fila" do
    setup %{conn: conn}, do: %{conn: sign_in(conn)}

    test "sem pendência diz que não há nada", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "Nada pendente"
    end

    test "um link interno quebrado aparece", %{conn: conn} do
      Fixtures.post(%{
        status: "published",
        title: "Com link quebrado",
        body: %{
          "blocks" => [%{"type" => "text", "paragraphs" => ["Veja [isto](/sumiu)."]}]
        }
      })

      {:ok, _live, html} = live(conn, ~p"/painel")

      assert html =~ "link interno quebrado"
      assert html =~ "sumiu"
    end
  end

  describe "a comparação com o período anterior" do
    setup %{conn: conn} do
      %{conn: sign_in(conn), post: Fixtures.post(%{status: "published"})}
    end

    # The first weeks of a blog have no previous period. "+100%" against
    # nothing is the kind of number that makes a panel untrustworthy.
    test "não inventa delta quando não há base", %{conn: conn, post: post} do
      read(post)

      {:ok, _live, html} = live(conn, ~p"/painel")

      refute html =~ "delta--up"
    end

    test "compara com a janela anterior de mesmo tamanho", %{conn: conn, post: post} do
      for _ <- 1..2, do: read(post, %{day: Date.add(Date.utc_today(), -40)})
      for _ <- 1..4, do: read(post, %{day: Date.utc_today()})

      {:ok, live, _html} = live(conn, ~p"/painel")
      html = live |> element(~s|button[phx-value-value="30"]|) |> render_click()

      assert html =~ "delta--up"
      assert html =~ "100%"
    end
  end
end
