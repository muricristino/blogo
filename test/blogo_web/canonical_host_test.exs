defmodule BlogoWeb.CanonicalHostTest do
  @moduledoc """
  The blog answers on two addresses — its own domain and the automatic one the
  server gave it, which never goes away. These pin which one wins and, just as
  importantly, that the rule stays out of the way where there is no domain.
  """
  use BlogoWeb.ConnCase

  alias Blogo.Fixtures

  defp on_host(conn, host), do: %{conn | host: host}

  describe "with a real domain configured" do
    setup do
      original = Application.get_env(:blogo, BlogoWeb.Endpoint)
      url = Keyword.put(original[:url] || [], :host, "muricristino.com")
      Application.put_env(:blogo, BlogoWeb.Endpoint, Keyword.put(original, :url, url))

      on_exit(fn -> Application.put_env(:blogo, BlogoWeb.Endpoint, original) end)
      :ok
    end

    test "another hostname is sent to the canonical one, permanently", %{conn: conn} do
      conn = conn |> on_host("ember-pebble-maple.axolutions.com.br") |> get("/")

      assert conn.status == 301
      assert redirected_to(conn, 301) == "https://muricristino.com/"
    end

    # A link someone shared to an article has to land on that article. Sending
    # every old address to the front page throws away the reason the link
    # existed.
    test "the path survives the move", %{conn: conn} do
      post = Fixtures.post()

      conn = conn |> on_host("ember-pebble-maple.axolutions.com.br") |> get("/#{post.slug}")

      assert redirected_to(conn, 301) == "https://muricristino.com/#{post.slug}"
    end

    test "the query string survives too", %{conn: conn} do
      conn = conn |> on_host("outro.exemplo.com") |> get("/?utm_source=x&page=2")

      assert redirected_to(conn, 301) == "https://muricristino.com/?utm_source=x&page=2"
    end

    test "the canonical host itself is served, not redirected", %{conn: conn} do
      conn = conn |> on_host("muricristino.com") |> get("/")

      assert conn.status == 200
    end

    # A health check arrives without a hostname worth speaking of; answering it
    # with a redirect makes a healthy container look broken.
    test "localhost is left alone", %{conn: conn} do
      assert conn |> on_host("localhost") |> get("/") |> Map.get(:status) == 200
    end
  end

  describe "with no domain configured" do
    test "nothing is redirected", %{conn: conn} do
      # This is a fresh clone and the test suite: the endpoint's host is
      # localhost, so there is no canonical address to send anyone to.
      conn = conn |> on_host("qualquer-coisa.exemplo.com") |> get("/")

      assert conn.status == 200
    end
  end
end
