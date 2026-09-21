defmodule BlogoWeb.SEO do
  @moduledoc """
  Head tags and structured data.

  The author is an entity, not a byline string: every post points at one
  stable `@id` on the author page, and that page carries `sameAs` to the
  profiles that prove the same person owns them. That is what lets a search
  for the author's name surface their articles.
  """
  use Phoenix.Component

  attr :conn, :map, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :canonical, :string, required: true
  attr :type, :string, default: "website"
  attr :published_at, :any, default: nil
  attr :author, :any, default: nil
  attr :json_ld, :any, default: nil

  def head(assigns) do
    ~H"""
    <title>{@title}</title>
    <meta :if={@description} name="description" content={@description} />
    <link rel="canonical" href={@canonical} />

    <meta property="og:type" content={@type} />
    <meta property="og:title" content={@title} />
    <meta :if={@description} property="og:description" content={@description} />
    <meta property="og:url" content={@canonical} />
    <meta
      :if={@published_at}
      property="article:published_time"
      content={DateTime.to_iso8601(@published_at)}
    />
    <meta :if={@author} property="article:author" content={@author.name} />

    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={@title} />
    <meta :if={@description} name="twitter:description" content={@description} />

    <script :if={@json_ld} type="application/ld+json">
      <%= Phoenix.HTML.raw(Jason.encode!(@json_ld)) %>
    </script>
    """
  end

  @doc "The author as a schema.org Person, with a stable @id."
  def person(author, base_url) do
    %{
      "@type" => "Person",
      "@id" => "#{base_url}/autor/#{author.slug}#person",
      "name" => author.name,
      "url" => "#{base_url}/autor/#{author.slug}",
      "jobTitle" => author.headline,
      "description" => author.bio,
      "sameAs" => author.same_as
    }
    |> drop_empty()
  end

  @doc "A published post as schema.org Article, authored by the Person above."
  def article(post, base_url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "@id" => "#{base_url}/#{post.slug}#article",
      "mainEntityOfPage" => "#{base_url}/#{post.slug}",
      "headline" => post.title,
      "description" => post.meta_description || post.subtitle,
      "inLanguage" => "pt-BR",
      "datePublished" => post.published_at && DateTime.to_iso8601(post.published_at),
      "dateModified" => post.updated_at && DateTime.to_iso8601(post.updated_at),
      "keywords" => Enum.join(post.topics, ", "),
      "author" => person(post.author, base_url),
      "publisher" => person(post.author, base_url)
    }
    |> drop_empty()
  end

  @doc "The author page, which is where the Person entity actually lives."
  def profile_page(author, posts, base_url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "ProfilePage",
      "mainEntity" => person(author, base_url),
      "hasPart" =>
        Enum.map(posts, fn p ->
          %{
            "@type" => "Article",
            "headline" => p.title,
            "url" => "#{base_url}/#{p.slug}",
            "datePublished" => p.published_at && DateTime.to_iso8601(p.published_at)
          }
        end)
    }
    |> drop_empty()
  end

  defp drop_empty(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" or v == [] end)
    |> Map.new()
  end
end
