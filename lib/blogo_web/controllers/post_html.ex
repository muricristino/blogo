defmodule BlogoWeb.PostHTML do
  use BlogoWeb, :html

  embed_templates "post_html/*"

  @doc """
  A date in the interface's language.

  The parts are translated as a pattern and not glued together here, because
  their order is part of the language: `3 de fevereiro de 2026` against
  `February 3, 2026`. A month name alone would put the English one in the
  Portuguese order.
  """
  def format_date(nil), do: ""

  def format_date(%DateTime{} = d) do
    pgettext("short date", "%{month} %{day}, %{year}",
      day: d.day,
      month: month_short(d.month),
      year: d.year
    )
  end

  def format_date_long(nil), do: ""

  def format_date_long(%DateTime{} = d) do
    pgettext("long date", "%{month} %{day}, %{year}",
      day: d.day,
      month: month_long(d.month),
      year: d.year
    )
  end

  @doc """
  What kind of post this is, in the reader's language.

  The three kinds are a vocabulary this site chose, not something the author
  typed, so they belong to the interface. Topics, which the author types, stay
  exactly as written.
  """
  def kind_label("ensaio"), do: gettext("essay")
  def kind_label("nota"), do: gettext("note")
  def kind_label("pagina"), do: gettext("page")
  def kind_label(other), do: other

  defp month_short(month) do
    Enum.at(
      [
        pgettext("month, short", "Jan"),
        pgettext("month, short", "Feb"),
        pgettext("month, short", "Mar"),
        pgettext("month, short", "Apr"),
        pgettext("month, short", "May"),
        pgettext("month, short", "Jun"),
        pgettext("month, short", "Jul"),
        pgettext("month, short", "Aug"),
        pgettext("month, short", "Sep"),
        pgettext("month, short", "Oct"),
        pgettext("month, short", "Nov"),
        pgettext("month, short", "Dec")
      ],
      month - 1
    )
  end

  defp month_long(month) do
    Enum.at(
      [
        pgettext("month", "January"),
        pgettext("month", "February"),
        pgettext("month", "March"),
        pgettext("month", "April"),
        pgettext("month", "May"),
        pgettext("month", "June"),
        pgettext("month", "July"),
        pgettext("month", "August"),
        pgettext("month", "September"),
        pgettext("month", "October"),
        pgettext("month", "November"),
        pgettext("month", "December")
      ],
      month - 1
    )
  end

  def initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  # The name a reader recognises, for the hosts a reader is likely to meet. An
  # unlisted host falls back to itself, which is never wrong — a label invented
  # from a domain is.
  @profiles %{
    "bsky.app" => "Bluesky",
    "dev.to" => "DEV",
    "github.com" => "GitHub",
    "gitlab.com" => "GitLab",
    "hex.pm" => "Hex",
    "instagram.com" => "Instagram",
    "linkedin.com" => "LinkedIn",
    "mastodon.social" => "Mastodon",
    "medium.com" => "Medium",
    "news.ycombinator.com" => "Hacker News",
    "scholar.google.com" => "Google Scholar",
    "speakerdeck.com" => "Speaker Deck",
    "stackoverflow.com" => "Stack Overflow",
    "substack.com" => "Substack",
    "twitter.com" => "X",
    "x.com" => "X",
    "youtube.com" => "YouTube"
  }

  @doc "The name of the place a profile lives, for a reader to recognise."
  def profile_name(url) do
    host =
      url |> URI.parse() |> Map.get(:host) |> to_string() |> String.replace_prefix("www.", "")

    Map.get(@profiles, host, host)
  end

  @doc """
  The account inside that place, when the address names one.

  The last segment, not the first: LinkedIn writes the handle behind `/in/`,
  and taking the first one labelled the link "in". A bare domain has no handle
  at all, and repeating the host as one would be noise.
  """
  def profile_handle(url) do
    case url |> URI.parse() |> Map.get(:path) |> to_string() |> String.split("/", trim: true) do
      [] -> nil
      segments -> segments |> List.last() |> String.trim_leading("@")
    end
  end

  @doc """
  The author's face, where there is one, and their initials where there is not.

  The photo comes from this application — the blog is self-hosted, and a face
  loaded from Gravatar or a CDN is a piece of the page its owner cannot turn
  off. `alt` is empty on purpose: the name is right beside it in text, so a
  screen reader that reads both says it twice.
  """
  attr :author, :map, required: true
  attr :class, :string, default: "ava"

  def ava(assigns) do
    assigns = assign(assigns, :src, BlogoWeb.AuthorPhotoController.path(assigns.author))

    ~H"""
    <img :if={@src} class={[@class, "ava--photo"]} src={@src} alt="" width="64" height="64" />
    <span :if={!@src} class={@class}>{initials(@author.name)}</span>
    """
  end

  @doc """
  Who wrote this, at the end of the article and at the top of the page about
  them.

  The profiles are the point. `same_as` already existed for the structured
  data, where it is what proves the person writing here is the person with
  those accounts — but a claim only a crawler can read does nothing for the
  reader making the same judgement. The links carry `rel="me"`, which is the
  same statement in the form the web itself checks: it is what Mastodon
  verifies a link against, and it is what IndieAuth reads.
  """
  attr :author, :map, required: true
  attr :label, :string, default: "Quem escreve"
  attr :bio, :boolean, default: true

  def author_note(assigns) do
    ~H"""
    <aside class="card au">
      <.ava author={@author} class="au-face" />

      <div class="au-body">
        <span class="kicker">{@label}</span>
        <p class="au-name">{@author.name}</p>
        <p :if={@author.headline} class="small au-role">
          {@author.headline}<span :if={@author.city}> · {@author.city}</span>
        </p>
        <p :if={@bio && @author.bio} class="au-bio">{@author.bio}</p>

        <ul :if={@author.same_as != []} class="au-links">
          <li :for={url <- @author.same_as}>
            <a class="au-link" href={url} rel="me noopener">
              <span class="au-link-where">{profile_name(url)}</span>
              <span :if={profile_handle(url)} class="au-link-who mono">{profile_handle(url)}</span>
            </a>
          </li>
        </ul>
      </div>
    </aside>
    """
  end

  @doc """
  The article's own diagram. Every published article has one, so the card and
  the list never fall back to a placeholder that says nothing.
  """
  attr :post, :map, required: true
  attr :caption, :boolean, default: false

  def hero(assigns) do
    ~H"""
    <div :if={@post.hero} class="hero">
      <.diagram
        form={@post.hero["form"]}
        data={@post.hero["data"] || %{}}
        label={@post.hero["alt"] || ""}
      />
      <p :if={@caption && @post.hero["caption"]} class="small">{@post.hero["caption"]}</p>
    </div>
    """
  end
end
