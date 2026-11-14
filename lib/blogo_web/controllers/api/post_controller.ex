defmodule BlogoWeb.Api.PostController do
  @moduledoc """
  Posts over HTTP, for the `blogo` CLI. The write format is the editor's
  markdown mode (`Blogo.Content.Markdown`) plus an optional hero, so a post
  pushed from a file and one typed in the editor are the same document.

  Every rule lives in `Blogo.Content` and `Post.changeset/2`; this module only
  translates between them and JSON.
  """
  use BlogoWeb, :controller

  alias Blogo.Content
  alias Blogo.Content.{Markdown, Post}

  def index(conn, _params) do
    posts =
      Enum.map(Content.list_posts(), fn post ->
        %{
          slug: post.slug,
          title: post.title,
          status: post.status,
          language: post.language,
          published_at: post.published_at,
          updated: post.updated_at,
          preview_url: preview_url(post)
        }
      end)

    json(conn, %{ok: true, posts: posts})
  end

  def show(conn, %{"slug" => slug}) do
    with_post(conn, slug, fn post -> json(conn, %{ok: true, post: render_post(post)}) end)
  end

  def update(conn, %{"slug" => slug} = params) do
    with {:ok, attrs} <- markdown_attrs(params),
         {:ok, attrs} <- put_hero(attrs, params),
         {:ok, attrs} <- put_language(attrs, params),
         {:ok, attrs} <- put_translation(attrs, slug) do
      before = Content.get_post_by_slug(slug)
      created? = is_nil(before)

      case Content.put_post_by_slug(slug, attrs) do
        {:ok, post} ->
          changed? = created? or post.lock_version != before.lock_version

          conn
          |> put_status(if created?, do: 201, else: 200)
          |> json(%{ok: true, created: created?, changed: changed?, post: render_post(post)})

        error ->
          fail(conn, error)
      end
    else
      error -> fail(conn, error)
    end
  end

  def publish(conn, %{"slug" => slug}) do
    with_post(conn, slug, fn post ->
      case Content.publish_post(post) do
        {:ok, post} -> json(conn, %{ok: true, post: render_post(post)})
        error -> fail(conn, error)
      end
    end)
  end

  def unpublish(conn, %{"slug" => slug}) do
    with_post(conn, slug, fn post ->
      case Content.unpublish_post(post) do
        {:ok, post} -> json(conn, %{ok: true, post: render_post(post)})
        error -> fail(conn, error)
      end
    end)
  end

  defp with_post(conn, slug, fun) do
    case Content.get_post_by_slug(slug) do
      nil -> error(conn, 404, "not_found", "no post at /#{slug}")
      post -> fun.(post)
    end
  end

  defp markdown_attrs(%{"markdown" => text}) when is_binary(text) and text != "" do
    case Markdown.from_markdown(text) do
      {:ok, attrs} -> {:ok, attrs}
      {:error, message} -> {:error, {:markdown, message}}
    end
  end

  defp markdown_attrs(_), do: {:error, {:invalid, "markdown is required (a string)"}}

  # `traducao_de: <slug>` is an instruction, not a field: it puts this post in
  # the original's translation group, which is what the language selector and
  # `hreflang` read. It is never written back by `get`, because a group has no
  # original to name.
  defp put_translation(attrs, slug) do
    case Map.pop(attrs, :translation_of) do
      {nil, attrs} ->
        {:ok, attrs}

      {^slug, _attrs} ->
        {:error, {:invalid, "traducao_de names this same post"}}

      {of, attrs} ->
        case Content.get_post_by_slug(of) do
          nil -> {:error, {:invalid, "traducao_de: no post at /#{of}"}}
          original -> {:ok, Map.put(attrs, :translation_group, original.translation_group)}
        end
    end
  end

  defp put_hero(attrs, %{"hero" => nil}), do: {:ok, Map.put(attrs, :hero, nil)}

  defp put_hero(attrs, %{"hero" => %{} = hero}) do
    hero = Map.drop(hero, ["type", "_uid", "note"])

    cond do
      hero["form"] not in Markdown.forms() ->
        {:error, {:hero, "form must be one of the seven: #{Enum.join(Markdown.forms(), ", ")}"}}

      not (is_binary(hero["alt"]) and String.trim(hero["alt"]) != "") ->
        {:error, {:hero, "alt is required and should state the finding in words"}}

      not is_map(Map.get(hero, "data", %{})) ->
        {:error, {:hero, "data must be an object"}}

      true ->
        {:ok, Map.put(attrs, :hero, Map.put_new(hero, "data", %{}))}
    end
  end

  defp put_hero(_attrs, %{"hero" => _}), do: {:error, {:hero, "must be an object or null"}}
  defp put_hero(attrs, _params), do: {:ok, attrs}

  defp put_language(attrs, %{"language" => lang}) when is_binary(lang),
    do: {:ok, Map.put(attrs, :language, lang)}

  defp put_language(attrs, _params), do: {:ok, attrs}

  defp render_post(%Post{} = post) do
    %{
      slug: post.slug,
      title: post.title,
      status: post.status,
      kind: post.kind,
      language: post.language,
      published_at: post.published_at,
      updated: post.updated_at,
      markdown: Markdown.to_markdown(post),
      hero: post.hero,
      translations: Content.translations_of(post),
      preview_url: preview_url(post),
      url: if(post.status == "published", do: url(~p"/#{post.slug}"))
    }
  end

  defp preview_url(post), do: url(~p"/editor/#{post.id}/previa")

  defp fail(conn, {:error, %Ecto.Changeset{} = changeset}) do
    fields =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
        end)
      end)

    message =
      Enum.map_join(fields, "; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

    error(conn, 422, "invalid", message, %{fields: fields})
  end

  defp fail(conn, {:error, :stale}),
    do: error(conn, 409, "stale", "the post changed while this request was being saved; retry")

  defp fail(conn, {:error, :no_author}),
    do: error(conn, 422, "no_author", "this blog has no author yet; create one in /painel")

  defp fail(conn, {:error, {:markdown, message}}), do: error(conn, 422, "markdown", message)
  defp fail(conn, {:error, {:hero, message}}), do: error(conn, 422, "hero", "hero " <> message)
  defp fail(conn, {:error, {:invalid, message}}), do: error(conn, 422, "invalid", message)

  defp error(conn, status, code, message, extra \\ %{}) do
    conn
    |> put_status(status)
    |> json(%{ok: false, error: Map.merge(%{code: code, message: message}, extra)})
  end
end
