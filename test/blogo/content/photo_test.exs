defmodule Blogo.Content.PhotoTest do
  @moduledoc """
  The metadata strip, on bytes with real structure.

  A test that compared sizes would pass on a function that truncated the file,
  so each of these asserts two things: the metadata is gone, and the picture is
  still there — dimensions still readable from the header the decoder reads
  them from, and, for PNG, the pixel data still inflating.
  """
  use ExUnit.Case, async: true

  alias Blogo.Content.Photo
  alias Blogo.Fixtures

  @gps "GPS:-23.5505,-46.6333"

  # Where a JPEG decoder reads the size: the frame header, which is the one
  # segment in the file that states it.
  defp jpeg_frame_size(bytes) do
    case :binary.match(bytes, <<0xFF, 0xC0>>) do
      {at, _} ->
        <<_::binary-size(at), 0xFF, 0xC0, _length::16, _precision, height::16, width::16,
          _::binary>> = bytes

        {width, height}

      :nomatch ->
        nil
    end
  end

  defp png_chunks(<<_signature::binary-size(8), rest::binary>>), do: png_chunks(rest, [])

  defp png_chunks(<<length::32, type::binary-size(4), rest::binary>>, acc) do
    <<data::binary-size(length), _crc::binary-size(4), tail::binary>> = rest
    png_chunks(tail, [{type, data} | acc])
  end

  defp png_chunks(<<>>, acc), do: Enum.reverse(acc)

  defp webp_chunks(<<"RIFF", _::little-32, "WEBP", rest::binary>>), do: webp_chunks(rest, [])

  defp webp_chunks(<<id::binary-size(4), length::little-32, rest::binary>>, acc) do
    pad = rem(length, 2)
    <<data::binary-size(length), _::binary-size(pad), tail::binary>> = rest
    webp_chunks(tail, [{id, data} | acc])
  end

  defp webp_chunks(<<>>, acc), do: Enum.reverse(acc)

  describe "JPEG" do
    test "the Exif segment goes, and the picture stays" do
      dirty = Fixtures.jpeg(width: 40, height: 30, metadata: [{0xE1, "Exif\0\0" <> @gps}])
      assert String.contains?(dirty, @gps)

      assert {:ok, "image/jpeg", clean} = Photo.clean(dirty)

      refute String.contains?(clean, @gps)
      refute String.contains?(clean, "Exif\0\0")
      assert jpeg_frame_size(clean) == {40, 30}
      assert <<0xFF, 0xD8, _::binary>> = clean
      assert String.ends_with?(clean, <<0xFF, 0xD9>>)
    end

    test "every APPn goes, not only the one carrying Exif" do
      dirty =
        Fixtures.jpeg(
          metadata: [
            {0xE1, "Exif\0\0" <> @gps},
            {0xE1, "http://ns.adobe.com/xap/1.0/\0" <> "<x:xmpmeta>#{@gps}</x:xmpmeta>"},
            {0xED, "Photoshop 3.0\0" <> @gps},
            {0xE2, "ICC_PROFILE\0" <> @gps}
          ]
        )

      assert {:ok, _, clean} = Photo.clean(dirty)

      refute String.contains?(clean, @gps)
      refute String.contains?(clean, "Photoshop")
      refute String.contains?(clean, "xmpmeta")
    end

    test "a comment segment goes too" do
      dirty = Fixtures.jpeg(metadata: [{0xFE, "tirada em casa"}])

      assert {:ok, _, clean} = Photo.clean(dirty)

      refute String.contains?(clean, "tirada em casa")
    end

    test "the quantisation table stays, because it is the picture" do
      assert {:ok, _, clean} = Photo.clean(Fixtures.jpeg(metadata: [{0xE1, "Exif\0\0" <> @gps}]))

      assert :binary.match(clean, <<0xFF, 0xDB>>) != :nomatch
      assert :binary.match(clean, <<0xFF, 0xDA>>) != :nomatch
    end

    # The scan is entropy-coded data, not segments: a byte inside it that looks
    # like a marker is not one, so it is copied rather than parsed.
    test "the scan is copied through untouched" do
      dirty = Fixtures.jpeg(metadata: [{0xE1, "Exif\0\0" <> @gps}])
      {at, _} = :binary.match(dirty, <<0xFF, 0xDA>>)
      scan = :binary.part(dirty, at, byte_size(dirty) - at)

      assert {:ok, _, clean} = Photo.clean(dirty)

      assert String.ends_with?(clean, scan)
    end

    test "a file that stops in the middle of a segment is refused" do
      dirty = Fixtures.jpeg(metadata: [{0xE1, "Exif\0\0" <> @gps}])
      truncated = :binary.part(dirty, 0, 12)

      assert Photo.clean(truncated) == {:error, :malformed}
    end

    test "a file with no frame header is not an image" do
      assert Photo.clean(<<0xFF, 0xD8, 0xFF, 0xD9>>) == {:error, :malformed}
    end
  end

  describe "PNG" do
    test "eXIf and the text chunks go, and the pixels stay" do
      dirty =
        Fixtures.png(
          width: 12,
          height: 9,
          metadata: [
            {"eXIf", @gps},
            {"tEXt", "Comment\0" <> @gps},
            {"iTXt", "XML:com.adobe.xmp\0\0\0\0\0" <> @gps},
            {"tIME", <<2026::16, 9, 24, 2, 0, 0>>}
          ]
        )

      assert String.contains?(dirty, @gps)

      assert {:ok, "image/png", clean} = Photo.clean(dirty)

      refute String.contains?(clean, @gps)
      types = clean |> png_chunks() |> Enum.map(&elem(&1, 0))
      assert types == ["IHDR", "IDAT", "IEND"]
    end

    test "the image still reads: same size, and the pixels still inflate" do
      dirty = Fixtures.png(width: 12, height: 9, metadata: [{"eXIf", @gps}])

      assert {:ok, _, clean} = Photo.clean(dirty)

      chunks = png_chunks(clean)
      assert {"IHDR", <<12::32, 9::32, 8, 2, _, _, _>>} = List.keyfind(chunks, "IHDR", 0)
      {"IDAT", data} = List.keyfind(chunks, "IDAT", 0)
      # 9 scanlines of a filter byte plus 12 pixels of 3 bytes each.
      assert byte_size(:zlib.uncompress(data)) == 9 * (1 + 12 * 3)
    end

    test "a chunk whose length runs past the end is refused" do
      <<head::binary-size(8), _::binary>> = Fixtures.png()
      assert Photo.clean(head <> <<9999::32>> <> "IHDR" <> "curto") == {:error, :malformed}
    end

    test "a file with no pixel data is not an image" do
      signature = :binary.part(Fixtures.png(), 0, 8)
      assert Photo.clean(signature) == {:error, :malformed}
    end
  end

  describe "WebP" do
    test "the EXIF and XMP chunks go" do
      dirty =
        Fixtures.webp(metadata: [{"EXIF", @gps}, {"XMP ", "<x:xmpmeta>#{@gps}</x:xmpmeta>"}])

      assert String.contains?(dirty, @gps)

      assert {:ok, "image/webp", clean} = Photo.clean(dirty)

      refute String.contains?(clean, @gps)
      assert clean |> webp_chunks() |> Enum.map(&elem(&1, 0)) == ["VP8X", "VP8L"]
    end

    # The header announces what the file carries. Left alone, it would promise
    # metadata that is no longer there — which some decoders forgive and others
    # do not.
    test "the flags that announced them are cleared" do
      dirty = Fixtures.webp(metadata: [{"EXIF", @gps}])
      assert {"VP8X", <<0x0C, _::binary>>} = dirty |> webp_chunks() |> List.keyfind("VP8X", 0)

      assert {:ok, _, clean} = Photo.clean(dirty)

      assert {"VP8X", <<0x00, _::binary>>} = clean |> webp_chunks() |> List.keyfind("VP8X", 0)
    end

    # The only number in the whole strip that is rewritten rather than copied.
    # Stale, it describes a file that no longer exists.
    test "the size in the RIFF header is rewritten to what is left" do
      dirty = Fixtures.webp(metadata: [{"EXIF", @gps}, {"XMP ", @gps}])

      assert {:ok, _, clean} = Photo.clean(dirty)

      assert <<"RIFF", declared::little-32, "WEBP", _::binary>> = clean
      assert declared == byte_size(clean) - 8
    end

    test "the canvas size survives" do
      dirty = Fixtures.webp(width: 64, height: 48, metadata: [{"EXIF", @gps}])

      assert {:ok, _, clean} = Photo.clean(dirty)

      {"VP8X", <<_flags, _, _, _, width::little-24, height::little-24>>} =
        clean |> webp_chunks() |> List.keyfind("VP8X", 0)

      assert {width + 1, height + 1} == {64, 48}
    end

    test "a container with no image chunk is refused" do
      body = "EXIF" <> <<byte_size(@gps)::little-32>> <> @gps
      riff = "RIFF" <> <<4 + byte_size(body)::little-32>> <> "WEBP" <> body

      assert Photo.clean(riff) == {:error, :malformed}
    end
  end

  describe "anything else" do
    test "a file that is not an image at all" do
      assert Photo.clean("não sou uma foto") == {:error, :unsupported}
    end

    test "an SVG, which has no format here and would be a script if served" do
      svg = "<svg onload=\"alert(1)\"></svg>"
      assert Photo.clean(svg) == {:error, :unsupported}
    end

    test "nothing" do
      assert Photo.clean("") == {:error, :unsupported}
    end
  end
end
