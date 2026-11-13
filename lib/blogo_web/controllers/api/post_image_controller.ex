defmodule BlogoWeb.Api.PostImageController do
  @moduledoc """
  A post's images over HTTP, for `blogo push` and `blogo get`.

  The bytes travel as base64 inside JSON so the API speaks one format. Every
  answer carries both digests, so the CLI can tell whether a local file is
  already on the server without sending it: `source_digest` matches a file
  pushed as it was, `digest` matches one that came down through `blogo get`.
  """
  use BlogoWeb, :controller

  alias Blogo.Content
  alias Blogo.Content.PostImage

  def index(conn, %{"slug" => slug}) do
    with_post(conn, slug, fn post ->
      json(conn, %{ok: true, images: Enum.map(Content.list_post_images(post), &render_image/1)})
    end)
  end

  def show(conn, %{"slug" => slug, "name" => parts}) do
    with_post(conn, slug, fn post ->
      case Content.get_post_image(post, Enum.join(parts, "/")) do
        nil ->
          error(conn, 404, "not_found", "no image #{Enum.join(parts, "/")} in /#{slug}")

        image ->
          json(conn, %{
            ok: true,
            image: Map.put(render_image(image), :data, Base.encode64(image.data))
          })
      end
    end)
  end

  def update(conn, %{"slug" => slug, "name" => parts} = params) do
    name = Enum.join(parts, "/")

    with_post(conn, slug, fn post ->
      with {:ok, bytes} <- decode(params["data"]),
           {:ok, image, outcome} <- Content.put_post_image(post, name, bytes) do
        conn
        |> put_status(if outcome == :created, do: 201, else: 200)
        |> json(%{ok: true, outcome: outcome, image: render_image(image)})
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          message =
            changeset
            |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
            |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

          error(conn, 422, "invalid", "#{name}: #{message}")

        {:error, :encoding} ->
          error(conn, 422, "invalid", "data is required: the image bytes in base64")
      end
    end)
  end

  def delete(conn, %{"slug" => slug, "name" => parts}) do
    name = Enum.join(parts, "/")

    with_post(conn, slug, fn post ->
      case Content.delete_post_image(post, name) do
        :ok -> json(conn, %{ok: true, deleted: name})
        {:error, :not_found} -> error(conn, 404, "not_found", "no image #{name} in /#{slug}")
      end
    end)
  end

  defp decode(data) when is_binary(data) do
    case Base.decode64(data, ignore: :whitespace) do
      {:ok, bytes} when bytes != "" -> {:ok, bytes}
      _ -> {:error, :encoding}
    end
  end

  defp decode(_), do: {:error, :encoding}

  defp render_image(%PostImage{} = image) do
    %{
      name: image.name,
      content_type: image.content_type,
      byte_size: image.byte_size,
      digest: image.digest,
      source_digest: image.source_digest,
      url: url(~p"/") |> String.trim_trailing("/") |> Kernel.<>(PostImage.path(image))
    }
  end

  defp with_post(conn, slug, fun) do
    case Content.get_post_by_slug(slug) do
      nil -> error(conn, 404, "not_found", "no post at /#{slug}")
      post -> fun.(post)
    end
  end

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{ok: false, error: %{code: code, message: message}})
  end
end
