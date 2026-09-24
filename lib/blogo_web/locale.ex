defmodule BlogoWeb.Locale do
  @moduledoc """
  Which language the *interface* speaks.

  Two facts decide it and they are not the same fact, so they are kept apart:
  what the browser asked for (`accept-language`) and what the reader picked by
  hand. The choice wins, always, and it survives the next visit because it
  lives in the session — a reader who has just said "English" and gets
  Portuguese back on the next page has been told their choice does not count.

  It never touches the address. An article keeps the one address it has; a
  second address serving the same text is the duplicate content the
  `BlogoWeb.CanonicalHost` plug exists to prevent, and the language of the menu
  is not a property of the article anyway.

  ## Request and socket

  A plug runs on the request; a LiveView reconnects over a websocket, which
  runs no plug at all. Guarding only the first is the same mistake as guarding
  only the request in `BlogoWeb.AdminAuth`, and the symptom is worse than it
  sounds: the interface would change language by itself on the first reconnect.
  So `call/2` covers the request and `on_mount/4` covers the socket, and both
  read the same two session keys.

  The plug writes the negotiated language into the session precisely so the
  socket can find it: `connect_info` carries the session, never the request
  headers. It is a separate key from the manual choice, and it is rewritten on
  every request, so changing the browser's language still changes the site —
  which would not be true if detection were remembered as if it had been
  chosen.

  ## Two spellings of the same language

  Gettext names a locale `pt_BR`, and HTML's `lang`, `xml:lang` and
  schema.org's `inLanguage` want the BCP 47 tag `pt-BR`. The hyphen is not
  interchangeable: `Expo.PluralForms` does not know `pt-BR`, so `ngettext/3`
  raises under it. Hence `tag/1`.
  """

  @behaviour Plug

  import Plug.Conn

  # {gettext locale, BCP 47 tag, what the reader sees, what fits on a button}
  @locales [
    {"pt_BR", "pt-BR", "Português", "PT"},
    {"en", "en", "English", "EN"}
  ]

  @default "pt_BR"

  @choice_key "locale"
  @detected_key "detected_locale"

  @doc "The interface languages, in the order the selector offers them."
  def supported, do: Enum.map(@locales, &elem(&1, 0))

  @doc "The language the site falls back to when nothing else decides."
  def default, do: @default

  @doc "The BCP 47 tag for a locale: what `lang` and `inLanguage` take."
  def tag(locale) do
    case Enum.find(@locales, &(elem(&1, 0) == locale)) do
      {_locale, tag, _label, _short} -> tag
      nil -> tag(@default)
    end
  end

  @doc "The language's own name, for the selector."
  def label(locale), do: find(locale, 2)

  @doc "Two letters, for the selector on a narrow screen."
  def short(locale), do: find(locale, 3)

  @doc """
  The locale a value names, or `nil`.

  Accepts either spelling, because the selector posts a tag and the session
  holds a locale.
  """
  def known(value) when is_binary(value) do
    case Enum.find(@locales, fn {locale, tag, _, _} -> value in [locale, tag] end) do
      {locale, _, _, _} -> locale
      nil -> nil
    end
  end

  def known(_value), do: nil

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    detected = negotiate(get_req_header(conn, "accept-language"))

    conn
    |> remember(@detected_key, detected)
    # Where the selector sends the reader back to: the address they are on,
    # unchanged. The language is not part of it.
    |> assign(:current_path, Phoenix.Controller.current_path(conn))
    |> apply_locale(known(get_session(conn, @choice_key)) || detected)
  end

  @doc """
  Records a language the reader picked, for this and every later request.
  """
  def choose(conn, value) do
    case known(value) do
      nil -> conn
      locale -> conn |> put_session(@choice_key, locale) |> apply_locale(locale)
    end
  end

  @doc """
  The socket's half of the same job. See the moduledoc.
  """
  def on_mount(:set_locale, _params, session, socket) do
    locale = known(session[@choice_key]) || known(session[@detected_key]) || @default
    Gettext.put_locale(BlogoWeb.Gettext, locale)
    {:cont, Phoenix.Component.assign(socket, locale: locale, locale_tag: tag(locale))}
  end

  @doc """
  The locale an `accept-language` header asks for, by descending quality.

  A tag we do not have in full still counts through its language subtag:
  `en-GB` is served by `en`, and `pt-PT` by the only Portuguese here. `*` means
  "anything", which is what the default already is.
  """
  def negotiate([]), do: @default
  def negotiate([header | _]), do: negotiate(header)

  def negotiate(header) when is_binary(header) do
    header
    |> String.split(",")
    |> Enum.map(&parse_range/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_tag, q} -> -q end)
    |> Enum.find_value(@default, fn {tag, _q} -> match_language(tag) end)
  end

  def negotiate(_header), do: @default

  defp parse_range(range) do
    case range |> String.trim() |> String.split(";") do
      [""] -> nil
      [tag] -> {tag, 1.0}
      [tag | params] -> {tag, quality(params)}
    end
  end

  # An unreadable q is not a reason to lose the whole header, and a range with
  # no q at all is the strongest one there is.
  defp quality(params) do
    Enum.find_value(params, 1.0, fn param ->
      with ["q", value] <- param |> String.trim() |> String.split("="),
           {q, _rest} <- Float.parse(value) do
        q
      else
        _ -> nil
      end
    end)
  end

  defp match_language(tag) do
    known(tag) || known_language(String.split(tag, "-") |> hd())
  end

  defp known_language(language) do
    language = String.downcase(language)

    Enum.find_value(@locales, fn {locale, tag, _, _} ->
      if language == tag |> String.split("-") |> hd() |> String.downcase(), do: locale
    end)
  end

  defp apply_locale(conn, locale) do
    Gettext.put_locale(BlogoWeb.Gettext, locale)

    conn
    |> assign(:locale, locale)
    |> assign(:locale_tag, tag(locale))
  end

  # Only written when it changed: every `put_session` sends a `set-cookie`, and
  # a header on every page for a value that never moves is noise a proxy has to
  # carry.
  defp remember(conn, key, value) do
    if get_session(conn, key) == value, do: conn, else: put_session(conn, key, value)
  end

  defp find(locale, index) do
    case Enum.find(@locales, &(elem(&1, 0) == locale)) do
      nil -> find(@default, index)
      entry -> elem(entry, index)
    end
  end
end
