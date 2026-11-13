defmodule BlogoWeb.PostImageController do
  @moduledoc """
  Serves the images inside articles, by the digest of their bytes.

  The address is the content: a replaced image is a new address, so every
  response can be cached for a year without anything to invalidate. It also
  means a draft's images are reachable only by someone who already has the
  digest, which the public pages never print for a draft.
  """
  use BlogoWeb, :controller

  alias Blogo.Content
  alias Blogo.Content.{Post, PostImage}

  @doc "The post's images as name → served address, which is what the renderer needs."
  def addresses(%Post{id: id} = post) when not is_nil(id),
    do: Map.new(Content.list_post_images(post), &{&1.name, PostImage.path(&1)})

  def addresses(_), do: %{}

  def show(conn, %{"file" => file}) do
    digest = file |> String.split(".", parts: 2) |> hd()

    case Regex.match?(~r/\A[0-9a-f]{64}\z/, digest) && Content.image_by_digest(digest) do
      image when is_map(image) ->
        conn
        |> put_resp_content_type(image.type, nil)
        |> put_resp_header("etag", ~s("#{image.digest}"))
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> respond(image)

      _ ->
        conn |> put_status(:not_found) |> text("Não encontrado")
    end
  end

  defp respond(conn, image) do
    etag = ~s("#{image.digest}")

    if Enum.any?(get_req_header(conn, "if-none-match"), &(&1 in [etag, "*"])) do
      send_resp(conn, :not_modified, "")
    else
      send_resp(conn, :ok, image.data)
    end
  end
end
