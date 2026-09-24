defmodule BlogoWeb.LocaleTest do
  @moduledoc """
  The interface answers in the reader's language; the article does not change
  language because the menu did.
  """
  use BlogoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Blogo.Fixtures
  alias BlogoWeb.Locale

  @password "senha-de-teste"

  defp pt(conn), do: put_req_header(conn, "accept-language", "pt-BR,pt;q=0.9,en;q=0.8")
  defp en(conn), do: put_req_header(conn, "accept-language", "en-GB,en;q=0.9,pt;q=0.4")

  describe "detection" do
    test "an English browser gets the interface in English", %{conn: conn} do
      Fixtures.post()

      html = conn |> en() |> get(~p"/") |> html_response(200)

      assert html =~ "Most read this month"
      assert html =~ "Read the essay"
      assert html =~ "min read"
      refute html =~ "Mais lidos este mês"
    end

    test "a Brazilian browser gets it in Portuguese", %{conn: conn} do
      Fixtures.post()

      html = conn |> pt() |> get(~p"/") |> html_response(200)

      assert html =~ "Mais lidos este mês"
      assert html =~ "Ler o ensaio"
      assert html =~ "min de leitura"
      refute html =~ "Most read this month"
    end

    test "no preference at all gets the declared default", %{conn: conn} do
      Fixtures.post()

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Mais lidos este mês"
    end

    test "a language we do not have falls back rather than 500s", %{conn: conn} do
      Fixtures.post()

      html =
        conn
        |> put_req_header("accept-language", "de-DE,de;q=0.9")
        |> get(~p"/")
        |> html_response(200)

      assert html =~ "Mais lidos este mês"
    end

    test "quality decides when the browser asks for both" do
      assert Locale.negotiate("pt-BR;q=0.2,en;q=0.9") == "en"
      assert Locale.negotiate("pt-BR;q=0.9,en;q=0.2") == "pt_BR"
      assert Locale.negotiate("en-GB") == "en"
      assert Locale.negotiate("pt-PT") == "pt_BR"
      assert Locale.negotiate("*") == Locale.default()
      assert Locale.negotiate([]) == Locale.default()
      # Unreadable input is not a reason to answer with a crash.
      assert Locale.negotiate("en;q=banana,pt;q=0.1") == "en"
      assert Locale.negotiate(nil) == Locale.default()
    end
  end

  describe "the manual choice" do
    test "wins over the browser and holds on the next request", %{conn: conn} do
      Fixtures.post()

      conn = post(conn, ~p"/idioma", %{"locale" => "en", "return_to" => "/"})
      assert redirected_to(conn) == "/"

      # The browser keeps asking for Portuguese; the reader already said no.
      html = conn |> recycle() |> pt() |> get(~p"/") |> html_response(200)

      assert html =~ "Most read this month"
      refute html =~ "Mais lidos este mês"
    end

    test "comes back to the same address, which never carries the language", %{conn: conn} do
      post = Fixtures.post()

      conn = post(conn, ~p"/idioma", %{"locale" => "en", "return_to" => "/#{post.slug}"})

      assert redirected_to(conn) == "/#{post.slug}"
    end

    test "refuses to send the reader off the site", %{conn: conn} do
      conn = post(conn, ~p"/idioma", %{"locale" => "en", "return_to" => "//evil.example.com"})

      assert redirected_to(conn) == "/"
    end

    test "a language the site does not have changes nothing", %{conn: conn} do
      Fixtures.post()

      conn = post(conn, ~p"/idioma", %{"locale" => "tlh", "return_to" => "/"})
      html = conn |> recycle() |> get(~p"/") |> html_response(200)

      assert html =~ "Mais lidos este mês"
    end

    # The name and the city used to be two fragments the template put in order,
    # and the formatter ate the space between them: "Muri Cristinoin São Paulo".
    test "the byline is one sentence in either language", %{conn: conn} do
      author = Fixtures.author(%{city: "São Paulo"})
      Fixtures.post(%{author: author})

      assert conn |> pt() |> get(~p"/") |> html_response(200) =~
               "escrito por #{author.name} em São Paulo"

      assert build_conn() |> en() |> get(~p"/") |> html_response(200) =~
               "written by #{author.name} in São Paulo"
    end

    test "the selector says which language is on", %{conn: conn} do
      Fixtures.post()

      html = conn |> en() |> get(~p"/") |> html_response(200)

      assert html =~ ~s(<button class="langbtn is-on")
      assert html =~ "Português"
      assert html =~ "English"
    end
  end

  describe "the article keeps its own language" do
    test "a Portuguese article read with an English menu stays Portuguese", %{conn: conn} do
      post = Fixtures.post(%{language: "pt-BR"})

      html = conn |> en() |> get(~p"/#{post.slug}") |> html_response(200)

      # The menu is English and the document is not.
      assert html =~ ~s(<html lang="pt-BR")
      assert html =~ "7 min read"
      refute html =~ ~s(<html lang="en")
    end

    test "an English article read with a Portuguese menu says so", %{conn: conn} do
      post = Fixtures.post(%{language: "en"})

      html = conn |> pt() |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ ~s(<html lang="en")
      assert html =~ "7 min de leitura"
    end

    test "the structured data declares the article's language, not the menu's", %{conn: conn} do
      post = Fixtures.post(%{language: "pt-BR"})

      html = conn |> en() |> get(~p"/#{post.slug}") |> html_response(200)

      assert html =~ ~s("inLanguage":"pt-BR")
      refute html =~ ~s("inLanguage":"en")
    end

    test "a listing takes the interface's language and marks each title", %{conn: conn} do
      Fixtures.post(%{language: "pt-BR", title: "Um ensaio em português"})

      html = conn |> en() |> get(~p"/") |> html_response(200)

      assert html =~ ~s(<html lang="en")
      assert html =~ ~s(lang="pt-BR")
    end

    test "the feed says which language each entry is in", %{conn: conn} do
      Fixtures.post(%{language: "en"})

      body = conn |> get(~p"/feed.xml") |> response(200)

      assert body =~ ~s(<entry xml:lang="en">)
    end
  end

  describe "the socket" do
    setup do
      Application.put_env(:blogo, :admin_password, @password)
      on_exit(fn -> Application.delete_env(:blogo, :admin_password) end)
      :ok
    end

    test "a LiveView keeps the language the request negotiated", %{conn: conn} do
      conn =
        conn
        |> en()
        |> post(~p"/auth/login", %{"password" => @password})
        |> recycle()
        |> en()

      {:ok, view, _html} = live(conn, ~p"/painel")

      # Reading the socket's own state rather than the rendered page: the
      # reconnect this guards against is a websocket that runs no plug, and the
      # locale living in the socket is exactly what makes it survive.
      assert socket_assigns(view).locale == "en"
      assert socket_assigns(view).locale_tag == "en"
    end

    test "the hook reads the same two session keys the plug writes" do
      socket = %Phoenix.LiveView.Socket{}

      assert {:cont, mounted} =
               Locale.on_mount(:set_locale, %{}, %{"detected_locale" => "en"}, socket)

      assert mounted.assigns.locale == "en"
      assert Gettext.get_locale(BlogoWeb.Gettext) == "en"

      # The manual choice wins here too, or the interface would change language
      # by itself the moment the socket reconnected.
      assert {:cont, mounted} =
               Locale.on_mount(
                 :set_locale,
                 %{},
                 %{"detected_locale" => "en", "locale" => "pt_BR"},
                 socket
               )

      assert mounted.assigns.locale == "pt_BR"
      assert Gettext.get_locale(BlogoWeb.Gettext) == "pt_BR"
    end

    test "an empty session falls back to the default rather than to nothing" do
      assert {:cont, mounted} =
               Locale.on_mount(:set_locale, %{}, %{}, %Phoenix.LiveView.Socket{})

      assert mounted.assigns.locale == Locale.default()
    end
  end

  describe "the translations themselves" do
    test "every interface string has a Portuguese translation" do
      # The msgids are English, so a string nobody translated reaches the
      # reader in English — and Portuguese is who this blog is written for.
      # The errors domain is Ecto's own and is not part of this.
      untranslated =
        "priv/gettext/pt_BR/LC_MESSAGES/default.po"
        |> Expo.PO.parse_file!()
        |> Map.fetch!(:messages)
        |> Enum.filter(&untranslated?/1)
        |> Enum.map(&message_id/1)

      assert untranslated == []
    end
  end

  defp untranslated?(%Expo.Message.Singular{msgstr: msgstr}), do: blank?(msgstr)

  defp untranslated?(%Expo.Message.Plural{msgstr: msgstr}),
    do: Enum.any?(Map.values(msgstr), &blank?/1)

  defp blank?(strings), do: Enum.all?(strings, &(String.trim(&1) == ""))

  defp message_id(%{msgid: msgid}), do: Enum.join(msgid)

  # `:sys.get_state` and not an assign helper, because LiveViewTest exposes the
  # rendered page and not the socket, and the socket is the thing under test.
  defp socket_assigns(view), do: :sys.get_state(view.pid).socket.assigns
end
