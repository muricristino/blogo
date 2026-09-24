defmodule Blogo.Content.Photo do
  @moduledoc """
  Takes an uploaded image apart and puts back only the image.

  A photo off a phone carries Exif, and Exif carries GPS: the latitude and
  longitude of where the shutter was pressed, which for a profile picture is
  usually someone's home. `/autor/:slug/foto` is public, so storing the file as
  it arrived would publish a coordinate its owner never typed anywhere, cannot
  see, and has no reason to expect. Nothing on any screen would contradict it —
  the same shape as the defect this project already records for the editor.

  **The cleaning happens on the way in, never on the way out.** What is in the
  column is what may be served; a filter on one route is a leak waiting for the
  second route that reads the same column.

  No image library is involved, because nothing here decodes an image. All
  three formats are containers whose metadata sits in labelled sections, and
  dropping a section is copying the others through byte for byte:

    * **JPEG** is a chain of `FF xx <length:16> <payload>` segments. `APPn` —
      where Exif, XMP, ICC and the Photoshop blocks live — and `COM` are
      dropped. From `SOS` on, the entropy-coded data is copied untouched to the
      end of the file.
    * **PNG** is a chain of `<length:32><type><data><crc:32>` chunks. `eXIf`,
      `tEXt`, `iTXt`, `zTXt` and `tIME` are dropped. No CRC is recomputed,
      because every chunk is either copied whole or not at all.
    * **WebP** is RIFF: `<fourcc><length:32 little><data>`, padded to even.
      `EXIF` and `XMP ` are dropped, the flags that announce them in `VP8X` are
      cleared, and the length in the RIFF header is rewritten. That length is
      the only number here that is not copied, and leaving it stale produces a
      file some decoders tolerate and others reject.

  Anything that does not parse is refused rather than stored as it came. The
  safe failure for a photo is not having one.

  **What this cannot do without decoding the image is honour Exif orientation.**
  A photo that leaned on that tag to stand upright is stored as its pixels
  actually are, so the panel says to rotate it before uploading. Fixing it
  properly means re-encoding, which does need a library this project does not
  carry.
  """

  import Bitwise

  @png_signature <<0x89, "PNG\r\n", 0x1A, 0x0A>>
  @png_drop ~w(eXIf tEXt iTXt zTXt tIME)
  @webp_drop ["EXIF", "XMP "]
  @webp_image ["VP8 ", "VP8L", "VP8X"]

  @doc """
  The image with its metadata removed, and what it turned out to be.

  The format comes from the bytes, never from the name or the content type the
  browser sent: both are typed by whoever uploads.
  """
  @spec clean(binary) :: {:ok, String.t(), binary} | {:error, :unsupported | :malformed}
  def clean(<<0x89, "PNG\r\n", 0x1A, 0x0A, rest::binary>>), do: png(rest)
  def clean(<<0xFF, 0xD8, rest::binary>>), do: jpeg(rest)
  def clean(<<"RIFF", _size::little-32, "WEBP", rest::binary>>), do: webp(rest)
  def clean(_), do: {:error, :unsupported}

  # ── PNG ───────────────────────────────────────────────────────────────────

  defp png(body) do
    with {:ok, chunks} <- png_chunks(body, []),
         [{"IHDR", _} | _] <- chunks,
         true <- Enum.any?(chunks, fn {type, _} -> type == "IDAT" end) do
      kept = Enum.reject(chunks, fn {type, _} -> type in @png_drop end)
      {:ok, "image/png", @png_signature <> Enum.map_join(kept, fn {_, raw} -> raw end)}
    else
      _ -> {:error, :malformed}
    end
  end

  defp png_chunks(<<length::32, type::binary-size(4), rest::binary>>, acc) do
    case rest do
      <<data::binary-size(length), crc::binary-size(4), tail::binary>> ->
        acc = [{type, <<length::32>> <> type <> data <> crc} | acc]

        # Whatever a tool appended after IEND is not part of the image.
        if type == "IEND", do: {:ok, Enum.reverse(acc)}, else: png_chunks(tail, acc)

      _ ->
        :error
    end
  end

  defp png_chunks(_, _), do: :error

  # ── JPEG ──────────────────────────────────────────────────────────────────

  defp jpeg(body) do
    case jpeg_segments(body, [], false) do
      {:ok, out} -> {:ok, "image/jpeg", <<0xFF, 0xD8>> <> out}
      :error -> {:error, :malformed}
    end
  end

  # A run of FF bytes between segments is padding, and legal.
  defp jpeg_segments(<<0xFF, 0xFF, rest::binary>>, acc, frame?),
    do: jpeg_segments(<<0xFF, rest::binary>>, acc, frame?)

  defp jpeg_segments(<<0xFF, marker, rest::binary>>, acc, frame?) do
    cond do
      # The scan and everything after it is entropy-coded data with restart
      # markers in it, not segments. It is copied to the end as it is.
      marker == 0xDA and frame? ->
        {:ok, IO.iodata_to_binary([Enum.reverse(acc), <<0xFF, marker>>, rest])}

      marker == 0xDA ->
        :error

      # Standalone markers: no length, nothing to skip.
      marker == 0x01 or marker in 0xD0..0xD7 ->
        jpeg_segments(rest, [<<0xFF, marker>> | acc], frame?)

      marker == 0xD9 ->
        :error

      true ->
        jpeg_segment(marker, rest, acc, frame?)
    end
  end

  defp jpeg_segments(_, _, _), do: :error

  defp jpeg_segment(marker, <<length::16, rest::binary>>, acc, frame?) when length >= 2 do
    payload_length = length - 2

    case rest do
      <<payload::binary-size(payload_length), tail::binary>> ->
        acc =
          if drop_segment?(marker),
            do: acc,
            else: [<<0xFF, marker, length::16>> <> payload | acc]

        jpeg_segments(tail, acc, frame? or frame_header?(marker))

      _ ->
        :error
    end
  end

  defp jpeg_segment(_, _, _, _), do: :error

  # APPn holds Exif, XMP, the ICC profile and the Photoshop blocks; COM is a
  # free-text comment. None of them is the picture.
  defp drop_segment?(marker), do: marker in 0xE0..0xEF or marker == 0xFE

  # SOF0..SOF15, minus the three markers that share the range and are not
  # frame headers: DHT, JPG and DAC.
  defp frame_header?(marker), do: marker in 0xC0..0xCF and marker not in [0xC4, 0xC8, 0xCC]

  # ── WebP ──────────────────────────────────────────────────────────────────

  defp webp(body) do
    with {:ok, chunks} <- webp_chunks(body, []),
         true <- Enum.any?(chunks, fn {id, _} -> id in @webp_image end) do
      payload =
        chunks
        |> Enum.reject(fn {id, _} -> id in @webp_drop end)
        |> Enum.map_join(fn chunk ->
          {_id, raw} = forget_dropped(chunk)
          raw
        end)

      # The declared size is rewritten rather than trusted: chunks just left.
      {:ok, "image/webp", "RIFF" <> <<4 + byte_size(payload)::little-32>> <> "WEBP" <> payload}
    else
      _ -> {:error, :malformed}
    end
  end

  defp webp_chunks(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp webp_chunks(<<id::binary-size(4), length::little-32, rest::binary>>, acc) do
    case rest do
      <<data::binary-size(length), tail::binary>> ->
        # Every chunk is padded to an even length. A writer that omitted the
        # final pad byte still produced a readable file, and the copy puts it
        # back.
        pad = rem(length, 2)
        tail = if pad == 1, do: drop_byte(tail), else: tail
        raw = id <> <<length::little-32>> <> data <> :binary.copy(<<0>>, pad)
        webp_chunks(tail, [{id, raw} | acc])

      _ ->
        :error
    end
  end

  defp webp_chunks(_, _), do: :error

  defp drop_byte(<<_::8, tail::binary>>), do: tail
  defp drop_byte(<<>>), do: <<>>

  # `VP8X` announces in a flag byte what the file carries. Dropping the EXIF
  # and XMP chunks without clearing their flags leaves the header promising
  # something no longer in the file.
  defp forget_dropped({"VP8X", <<head::binary-size(8), flags, rest::binary>>}),
    do: {"VP8X", head <> <<flags &&& 0xF3>> <> rest}

  defp forget_dropped(chunk), do: chunk
end
