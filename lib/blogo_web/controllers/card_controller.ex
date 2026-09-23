defmodule BlogoWeb.CardController do
  @moduledoc """
  Serves the social card for an article.

  The card is generated on request rather than stored: it takes about 17ms and
  changes whenever the title or the hero changes, so a stored copy would be one
  more thing that can go stale. What keeps that cheap is the ETag — a crawler
  that already has the card gets 304 and no image is drawn at all.
  """
  use BlogoWeb, :controller

  require Logger

  alias Blogo.{Card, Content}

  def show(conn, %{"slug" => slug}) do
    # The URL ends in .png because some validators look at the extension rather
    # than the content type; the slug itself never contains one.
    slug = String.replace_suffix(slug, ".png", "")

    case Content.get_published_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> text("Não encontrado")

      post ->
        serve(conn, post)
    end
  end

  defp serve(conn, post) do
    etag = etag_for(post)

    if stale?(conn, etag) do
      case Card.png(post, post.author) do
        {:ok, png} ->
          conn
          |> put_resp_content_type("image/png", nil)
          |> put_resp_header("etag", etag)
          # A card changes only when the post does, and the ETag catches that.
          |> put_resp_header("cache-control", "public, max-age=3600")
          |> send_resp(200, png)

        {:error, reason} ->
          # A card that fails to draw must not take the article's page with it:
          # the crawler falls back to no image, which is what it had before.
          Logger.error("card falhou para #{post.slug}: #{inspect(reason)}")
          conn |> put_status(:internal_server_error) |> text("não foi possível gerar a imagem")
      end
    else
      send_resp(conn, 304, "")
    end
  end

  defp etag_for(post) do
    hash =
      :crypto.hash(:sha256, "#{post.id}-#{DateTime.to_unix(post.updated_at)}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    ~s("#{hash}")
  end

  defp stale?(conn, etag) do
    conn |> get_req_header("if-none-match") |> Enum.all?(&(&1 != etag))
  end
end
