defmodule Blogo.Fixtures do
  @moduledoc "Minimal records for tests: one author, one published post."

  alias Blogo.Content

  def author(attrs \\ %{}) do
    {:ok, author} =
      Content.create_author(
        Map.merge(
          %{
            name: "Muri Cristino",
            slug: "muri-cristino-#{System.unique_integer([:positive])}",
            headline: "Engenheiro de software",
            bio: "Escrevo sobre o que eu meço.",
            same_as: ["https://github.com/muricristino"]
          },
          attrs
        )
      )

    author
  end

  @png_signature <<0x89, "PNG\r\n", 0x1A, 0x0A>>

  @doc """
  A PNG built here, chunk by chunk, so the tests work on bytes with a real
  structure: the application takes an upload apart to strip its metadata, and a
  header followed by filler would never survive that — nor should it.

  `metadata:` takes `{type, data}` chunks to plant, `width:`/`height:` size the
  image, and `noise: true` fills it with random pixels, which is how a fixture
  gets past the size limit without being 2 MB of literal.
  """
  def png(opts \\ []) do
    width = Keyword.get(opts, :width, 8)
    height = Keyword.get(opts, :height, 8)
    planted = Keyword.get(opts, :metadata, [])

    # Each scanline is preceded by its filter byte, and filter 0 is "none".
    # Noise has to be fresh per line: a repeated row deflates to nothing, and a
    # fixture meant to be big would come out at 15 kB.
    raw =
      if Keyword.get(opts, :noise, false) do
        for _ <- 1..height, into: <<>>, do: <<0>> <> :crypto.strong_rand_bytes(width * 3)
      else
        :binary.copy(<<0>> <> :binary.copy(<<120, 90, 200>>, width), height)
      end

    @png_signature <>
      png_chunk("IHDR", <<width::32, height::32, 8, 2, 0, 0, 0>>) <>
      Enum.map_join(planted, fn {type, data} -> png_chunk(type, data) end) <>
      png_chunk("IDAT", :zlib.compress(raw)) <>
      png_chunk("IEND", "")
  end

  defp png_chunk(type, data) do
    <<byte_size(data)::32>> <> type <> data <> <<:erlang.crc32(type <> data)::32>>
  end

  @doc """
  A JPEG in segments, with `metadata:` taking `{marker, payload}` to plant —
  `0xE1` for the Exif the strip has to remove.

  It is a container, not a decodable picture: there is no encoder here to make
  one. That a real photograph still opens after being cleaned is covered by
  `test/support/fotos/com_gps.jpg`, which came out of a real encoder.
  """
  def jpeg(opts \\ []) do
    width = Keyword.get(opts, :width, 8)
    height = Keyword.get(opts, :height, 8)
    planted = Keyword.get(opts, :metadata, [])

    <<0xFF, 0xD8>> <>
      jpeg_segment(0xE0, "JFIF" <> <<0, 1, 1, 0, 0, 1, 0, 1, 0, 0>>) <>
      Enum.map_join(planted, fn {marker, payload} -> jpeg_segment(marker, payload) end) <>
      jpeg_segment(0xDB, <<0>> <> :binary.copy(<<16>>, 64)) <>
      jpeg_segment(0xC0, <<8, height::16, width::16, 1, 1, 0x11, 0>>) <>
      jpeg_segment(0xDA, <<1, 1, 0, 0, 63, 0>>) <>
      <<0xAA, 0xBB, 0xCC, 0xFF, 0xD9>>
  end

  defp jpeg_segment(marker, payload) do
    <<0xFF, marker, byte_size(payload) + 2::16>> <> payload
  end

  @doc """
  A WebP container in the extended form, which is the one that can carry
  metadata: `VP8X` with the Exif and XMP flags raised, the image chunk, and the
  `EXIF`/`XMP ` chunks themselves.
  """
  def webp(opts \\ []) do
    width = Keyword.get(opts, :width, 8)
    height = Keyword.get(opts, :height, 8)
    planted = Keyword.get(opts, :metadata, [])
    # Bits, from the most significant: reserved, reserved, ICC, alpha, Exif,
    # XMP, animation, reserved.
    flags = if planted == [], do: 0x00, else: 0x0C

    chunks =
      webp_chunk("VP8X", <<flags, 0, 0, 0>> <> <<width - 1::little-24, height - 1::little-24>>) <>
        webp_chunk("VP8L", <<0x2F, 0, 0, 0, 0>>) <>
        Enum.map_join(planted, fn {id, data} -> webp_chunk(id, data) end)

    "RIFF" <> <<4 + byte_size(chunks)::little-32>> <> "WEBP" <> chunks
  end

  defp webp_chunk(id, data) do
    pad = rem(byte_size(data), 2)
    id <> <<byte_size(data)::little-32>> <> data <> :binary.copy(<<0>>, pad)
  end

  def post(attrs \\ %{}) do
    a = attrs[:author] || author()

    {:ok, post} =
      Content.create_post(
        %{
          title: "Um título",
          subtitle: "Uma linha de apoio.",
          slug: "um-titulo-#{System.unique_integer([:positive])}",
          status: "published",
          published_at: DateTime.utc_now() |> DateTime.truncate(:second),
          reading_minutes: 7,
          topics: ["avaliação"],
          meta_description: "Descrição para busca.",
          body: %{"blocks" => [%{"type" => "text", "paragraphs" => ["Olá."]}]},
          hero: %{"form" => "fluxo", "data" => %{"steps" => []}, "alt" => "Um fluxo"},
          author_id: a.id
        }
        |> Map.merge(Map.drop(attrs, [:author]))
      )

    %{post | author: a}
  end
end
