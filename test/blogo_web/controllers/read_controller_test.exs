defmodule BlogoWeb.ReadControllerTest do
  @moduledoc """
  The only route that lets an anonymous request write a row. These cases are
  about what it refuses, because a reading figure that can be invented is worse
  than no reading figure — it gets used to decide what to write next.
  """
  use BlogoWeb.ConnCase

  alias Blogo.Analytics
  alias Blogo.Fixtures

  defp beacon(conn, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/leitura", params)
  end

  defp token(slug), do: BlogoWeb.ReadController.token(slug)

  setup do
    %{post: Fixtures.post(%{status: "published"})}
  end

  test "uma leitura assinada é registrada", %{conn: conn, post: post} do
    conn =
      beacon(conn, %{
        "token" => token(post.slug),
        "depth" => 95,
        "seconds" => 240,
        "referrer" => "https://www.google.com/search?q=x"
      })

    assert response(conn, 204)

    assert %{reads: 1, completion: 100} = Analytics.totals(Analytics.window(7))
    assert [%{source: "busca"}] = Analytics.sources(Analytics.window(7))
  end

  test "sem token não conta", %{conn: conn} do
    conn = beacon(conn, %{"depth" => 90, "seconds" => 100})

    assert response(conn, 204)
    refute Analytics.measuring?()
  end

  test "token inventado não conta", %{conn: conn} do
    conn = beacon(conn, %{"token" => "nao-e-um-token", "depth" => 90, "seconds" => 100})

    assert response(conn, 204)
    refute Analytics.measuring?()
  end

  # A token is bound to the article it was issued for, so one article's page
  # cannot be used to inflate another's numbers.
  test "token de um artigo não serve para outro", %{conn: conn} do
    outro = Fixtures.post(%{status: "published"})
    conn = beacon(conn, %{"token" => token("endereco-que-nao-existe"), "depth" => 90})

    assert response(conn, 204)
    assert Analytics.by_post(Analytics.window(7)) == %{}
    refute Map.has_key?(Analytics.by_post(Analytics.window(7)), outro.id)
  end

  test "rascunho não acumula leitura", %{conn: conn} do
    rascunho = Fixtures.post(%{status: "draft", hero: nil})
    conn = beacon(conn, %{"token" => token(rascunho.slug), "depth" => 90})

    assert response(conn, 204)
    refute Analytics.measuring?()
  end

  # The browser has already navigated away; a status code telling a forger why
  # their token failed is free help for the next attempt.
  test "responde 204 mesmo quando recusa", %{conn: conn} do
    assert beacon(conn, %{"token" => "lixo"}) |> response(204) == ""
  end

  test "valores absurdos são cortados, não recusados", %{conn: conn, post: post} do
    beacon(conn, %{
      "token" => token(post.slug),
      "depth" => 10_000,
      "seconds" => 999_999
    })

    assert %{avg_seconds: seconds} = Analytics.totals(Analytics.window(7))
    assert seconds == Blogo.Analytics.Read.max_seconds()
  end
end
