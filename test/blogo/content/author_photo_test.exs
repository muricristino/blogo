defmodule Blogo.Content.AuthorPhotoTest do
  @moduledoc """
  The author's photo, stored in the database because nothing else in this
  deployment survives a deploy: the container is replaced and mounts no volume.

  Every test that saves reads the bytes back out of Postgres with a query of
  its own. Asserting on the struct the changeset returned would prove only that
  the changeset agrees with itself — and `:photo` is declared
  `load_in_query: false`, so a struct read back the ordinary way does not even
  carry it.
  """
  use Blogo.DataCase

  import Ecto.Query

  alias Blogo.Content
  alias Blogo.Content.Author
  alias Blogo.Fixtures
  alias Blogo.Repo

  defp stored(author) do
    Repo.one(
      from a in Author,
        where: a.id == ^author.id,
        select: %{data: a.photo, type: a.photo_type, digest: a.photo_digest}
    )
  end

  describe "storing a photo" do
    test "the bytes reach the database" do
      author = Fixtures.author()
      png = Fixtures.png()

      assert {:ok, _} = Content.put_author_photo(author, png)

      saved = stored(author)
      assert saved.data == png
      assert saved.type == "image/png"
      assert saved.digest == Base.encode16(:crypto.hash(:sha256, png), case: :lower)
    end

    test "a JPEG and a WebP are stored as what they are" do
      jpeg = Fixtures.author() |> tap(&Content.put_author_photo(&1, Fixtures.jpeg())) |> stored()
      webp = Fixtures.author() |> tap(&Content.put_author_photo(&1, Fixtures.webp())) |> stored()

      assert jpeg.type == "image/jpeg"
      assert webp.type == "image/webp"
    end

    # The browser sends a name and a content type that whoever uploads chose,
    # so the format is read from the bytes. A `.png` that is not a PNG would
    # otherwise be served as one and break on every article.
    test "a file that is not an image is refused, whatever it is called" do
      author = Fixtures.author()

      assert {:error, changeset} = Content.put_author_photo(author, "not an image at all")
      assert "precisa ser PNG, JPEG ou WebP" in errors_on(changeset).photo
      assert stored(author).data == nil
    end

    test "an HTML file dressed as a photo does not get through" do
      author = Fixtures.author()

      assert {:error, _} = Content.put_author_photo(author, "<svg onload=alert(1)></svg>")
      assert stored(author).data == nil
    end

    # An 8 MB file behind a 64px avatar is bandwidth spent on every visit. The
    # browser is asked to refuse it too, but the browser is not the guard.
    test "a photo past the limit is refused" do
      author = Fixtures.author()
      # A real image, not a blob: noise does not compress, so the pixels alone
      # carry it past the ceiling.
      big = Fixtures.png(width: 900, height: 800, noise: true)
      assert byte_size(big) > Author.max_photo_bytes()

      assert {:error, changeset} = Content.put_author_photo(author, big)
      assert "passa de 2 MB" in errors_on(changeset).photo
      assert stored(author).data == nil
    end

    test "a second photo replaces the first" do
      author = Fixtures.author()
      {:ok, _} = Content.put_author_photo(author, Fixtures.png())
      first = stored(author)

      {:ok, _} = Content.put_author_photo(author, Fixtures.jpeg())
      second = stored(author)

      refute second.digest == first.digest
      assert second.type == "image/jpeg"
    end
  end

  describe "taking it off" do
    test "the column is emptied, not left with a dangling type" do
      author = Fixtures.author()
      {:ok, _} = Content.put_author_photo(author, Fixtures.png())

      assert {:ok, _} = Content.delete_author_photo(author)

      assert stored(author) == %{data: nil, type: nil, digest: nil}
    end
  end

  describe "reading it back" do
    test "author_photo/1 answers with what to serve and what to call it" do
      author = Fixtures.author()
      png = Fixtures.png()
      {:ok, _} = Content.put_author_photo(author, png)

      assert %{data: ^png, type: "image/png", digest: digest} =
               Content.author_photo(author.slug)

      assert String.length(digest) == 64
    end

    test "an author with no photo has nothing to serve" do
      assert Content.author_photo(Fixtures.author().slug) == nil
    end

    test "a slug nobody has is not an error" do
      assert Content.author_photo("ninguem") == nil
    end
  end

  describe "what gets stored is stripped of its metadata" do
    @photo_with_gps Path.join(__DIR__, "../../support/fotos/com_gps.jpg")

    # A photograph out of a real encoder, carrying a real Exif block with real
    # GPS tags in it — the file a phone would hand over. `/autor/:slug/foto` is
    # public, so whatever stays in this column is published.
    test "a photo's GPS coordinates never reach the database" do
      author = Fixtures.author()
      original = File.read!(@photo_with_gps)

      assert String.contains?(original, "Exif\0\0")
      assert String.contains?(original, "BLOGO-CASA-DO-AUTOR")

      assert {:ok, _} = Content.put_author_photo(author, original)

      saved = stored(author).data
      refute String.contains?(saved, "BLOGO-CASA-DO-AUTOR")
      refute String.contains?(saved, "Exif\0\0")
      refute String.contains?(saved, "Photoshop")
      assert byte_size(saved) < byte_size(original)
    end

    test "and the photograph still is one afterwards" do
      author = Fixtures.author()
      {:ok, _} = Content.put_author_photo(author, File.read!(@photo_with_gps))

      saved = stored(author).data

      # Same picture: the frame header a decoder reads the size from still says
      # what it said, and the file still opens and closes as a JPEG.
      {at, _} = :binary.match(saved, <<0xFF, 0xC0>>)

      <<_::binary-size(at), 0xFF, 0xC0, _length::16, _precision, height::16, width::16,
        _::binary>> = saved

      assert {width, height} == {160, 160}
      assert <<0xFF, 0xD8, _::binary>> = saved
      assert String.ends_with?(saved, <<0xFF, 0xD9>>)
    end

    # A file that cannot be taken apart cannot be stripped, and storing it as
    # it came is the one outcome this must never have.
    test "an image that does not parse is refused rather than stored intact" do
      author = Fixtures.author()
      truncated = :binary.part(File.read!(@photo_with_gps), 0, 400)

      assert {:error, changeset} = Content.put_author_photo(author, truncated)
      assert "está corrompida: não deu para ler a imagem inteira" in errors_on(changeset).photo
      assert stored(author).data == nil
    end

    # The digest is the cache key for the bytes that will be served, so it has
    # to be taken after the strip, not before.
    test "the digest is of the cleaned bytes, not of the file that arrived" do
      author = Fixtures.author()
      original = File.read!(@photo_with_gps)
      {:ok, _} = Content.put_author_photo(author, original)

      saved = stored(author)

      assert saved.digest == Base.encode16(:crypto.hash(:sha256, saved.data), case: :lower)
      refute saved.digest == Base.encode16(:crypto.hash(:sha256, original), case: :lower)
    end
  end

  describe "the rest of the application never carries the bytes" do
    # Every post query preloads its author. If the photo loaded with the
    # struct, the index, the article, the feed and the social card would each
    # fetch the image to render a page that does not show it.
    test "a loaded author does not bring the photo along" do
      author = Fixtures.author()
      {:ok, _} = Content.put_author_photo(author, Fixtures.png())

      loaded = Content.get_author!(author.id)

      assert loaded.photo == nil
      # What is left is enough to know there is one, and to build its address.
      assert loaded.photo_type == "image/png"
      assert Author.photo?(loaded)
    end

    test "photo?/1 says no when there is no photo" do
      refute Author.photo?(Fixtures.author())
    end
  end
end
