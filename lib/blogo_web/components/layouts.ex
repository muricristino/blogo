defmodule BlogoWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use BlogoWeb, :controller` and
  `use BlogoWeb, :live_view`.
  """
  use BlogoWeb, :html

  embed_templates "layouts/*"

  @doc """
  The line under every page: who writes the blog, and from where.

  One string holding both names rather than a name plus a separate phrase.
  Where the city goes in the sentence is part of the language, and two
  fragments glued together in template order decide that for every language at
  once — the space between them was lost to the formatter the first time, which
  is how this was noticed.
  """
  def byline(%{city: city} = author) when is_binary(city) and city != "" do
    gettext("written by %{name} in %{city}", name: author.name, city: city)
  end

  def byline(author), do: gettext("written by %{name}", name: author.name)

  @doc """
  The language of the interface, as two buttons.

  A form and not a link: it changes what the session remembers, and a GET that
  changes state is a GET a crawler can trip over. `return_to` is the address the
  reader is on — the same one they get back, because the language of the menu is
  not part of an article's address.

  Not a `<select>`: two options are two buttons, and a select needs a submit
  button beside it or JavaScript to be usable at all.

  It is rendered twice and shown once. Two 44px targets do not fit in the bar
  beside the brand and the navigation at 320px — the bar would overflow the
  viewport — so on a phone the picker sits in the footer and the bar carries it
  from 760px up.
  """
  attr :locale, :string, required: true
  attr :return_to, :string, required: true
  attr :place, :string, values: ~w(bar foot), required: true

  def language_picker(assigns) do
    ~H"""
    <form class={["langsw", "langsw--#{@place}"]} action={~p"/idioma"} method="post">
      <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
      <input type="hidden" name="return_to" value={@return_to} />
      <button
        :for={locale <- BlogoWeb.Locale.supported()}
        class={["langbtn", locale == @locale && "is-on"]}
        type="submit"
        name="locale"
        value={locale}
        lang={BlogoWeb.Locale.tag(locale)}
        aria-current={locale == @locale && "true"}
      >
        <%!-- The full name is the accessible name; the two letters are what fits
              beside the brand at 320px. --%>
        <span class="sr-only">{BlogoWeb.Locale.label(locale)}</span>
        <span aria-hidden="true">{BlogoWeb.Locale.short(locale)}</span>
      </button>
    </form>
    """
  end
end
