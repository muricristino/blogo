defmodule BlogoWeb.FaviconTest do
  @moduledoc """
  The tab icon is the same open book the header draws. Nothing enforces that on
  its own — the header is a component and the favicon is a file — so these pin
  the two together. Someone who redraws the logo and forgets the favicon gets a
  failing test instead of a blog whose tab still wears the old mark.
  """
  use BlogoWeb.ConnCase

  @svg "priv/static/favicon.svg"
  @png "priv/static/apple-touch-icon.png"
  @ico "priv/static/favicon.ico"
  @header "lib/blogo_web/components/layouts/app.html.heex"

  defp read(path), do: Path.join(File.cwd!(), path) |> File.read!()

  # The `d` attributes are the drawing. Comparing them is what makes the favicon
  # a copy of the logo rather than something that merely resembles it. The
  # header holds other icons too — search, the theme toggle — so the claim is
  # that every path the favicon draws is still drawn in the header, not that the
  # two files carry the same set.
  defp paths(source),
    do: ~r/\sd="(M[^"]+)"/ |> Regex.scan(source, capture: :all_but_first) |> List.flatten()

  test "the favicon draws the same paths as the header logo" do
    header = paths(read(@header))
    favicon = paths(read(@svg))

    assert favicon != [], "the favicon stopped carrying a drawing"
    assert length(favicon) == 2, "the logo is two strokes; the favicon has #{length(favicon)}"

    for path <- favicon do
      assert path in header,
             "the favicon draws a path the header no longer has — the logo changed in one place"
    end
  end

  # The one file nobody had written: it arrived with the generator, as a
  # transparent 64x64 PNG named .ico, and survived the favicon work because the
  # tests asked about the two files that had just been made. A browser that does
  # not take an SVG icon falls back to this one and shows nothing.
  test "the .ico is really an ICO, and carries more than one size" do
    ico = read(@ico)

    # ICONDIR: reserved 0, type 1 (icon), then the image count.
    assert <<0, 0, 1, 0, count::16-little, rest::binary>> = ico
    assert count >= 2, "an .ico carrying one size has no reason to exist beside the SVG"

    sizes =
      for i <- 0..(count - 1) do
        <<_::binary-size(i * 16), w, h, _::binary>> = rest
        {w, h}
      end

    assert {16, 16} in sizes
    assert {32, 32} in sizes
    refute Enum.any?(sizes, &(&1 == {0, 0})), "a size of 0 means 256px, which this is not"
  end

  test "the .ico is not the generator's transparent placeholder" do
    ico = read(@ico)

    refute match?(<<137, 80, 78, 71, _::binary>>, ico), "it is a PNG wearing an .ico name"
    assert byte_size(ico) > 500
  end

  test "the touch icon is a real PNG, not an empty file" do
    png = read(@png)

    assert <<137, 80, 78, 71, 13, 10, 26, 10, _::binary>> = png
    assert byte_size(png) > 500
  end

  # A favicon has no `currentColor` to inherit: it is drawn outside the page.
  # A stroke left as `currentColor` renders black on every tab, which is the
  # failure that looks like a design choice.
  test "the favicon commits to literal colours" do
    # Comments stripped first: the file explains why it cannot use
    # `currentColor`, and that sentence is not a colour declaration.
    drawing = String.replace(read(@svg), ~r/<!--.*?-->/s, "")

    refute drawing =~ "currentColor"
    assert drawing =~ ~r/#[0-9a-fA-F]{6}/
  end

  test "the page points at all three" do
    html = build_conn() |> get(~p"/") |> html_response(200)

    assert html =~ ~s(rel="icon")
    assert html =~ "/favicon.svg"
    assert html =~ "/apple-touch-icon.png"
  end

  # Plug.Static answers before the router. A file called robots.txt would win
  # over the generated one and the panel's crawler choice would quietly stop
  # meaning anything.
  test "robots.txt is not served as a static file" do
    refute "robots.txt" in BlogoWeb.static_paths()
    refute File.exists?(Path.join(File.cwd!(), "priv/static/robots.txt"))
  end

  # Android takes a shortcut's icon from the manifest or from a large PNG, not
  # from the 48px in the .ico — which is why the home screen showed a globe
  # while the tab was fine.
  describe "the Android shortcut" do
    test "the manifest is served and names the site from the database", %{conn: conn} do
      Blogo.Content.update_site(%{"name" => "Um Nome Qualquer"})

      body = conn |> get(~p"/manifest.json") |> response(200)
      manifest = Jason.decode!(body)

      assert manifest["name"] == "Um Nome Qualquer"
      assert manifest["start_url"] == "/"
      assert manifest["theme_color"]
    end

    test "it offers the two sizes Android asks for, and they are maskable" do
      manifest = build_conn() |> get(~p"/manifest.json") |> response(200) |> Jason.decode!()

      sizes = Enum.map(manifest["icons"], & &1["sizes"])
      assert "192x192" in sizes
      assert "512x512" in sizes

      # Without `maskable`, a launcher that crops to a circle cuts the drawing.
      assert Enum.all?(manifest["icons"], &String.contains?(&1["purpose"], "maskable"))
    end

    # The .ico shipped for weeks as a transparent PNG with the wrong extension,
    # answering 200 the whole time. Responding is not being.
    test "the icons are PNGs of the size they claim" do
      for {file, expected} <- [{"icon-192.png", 192}, {"icon-512.png", 512}] do
        png = read("priv/static/#{file}")

        assert <<137, 80, 78, 71, 13, 10, 26, 10, _::binary-size(4), "IHDR", w::32, h::32,
                 _::binary>> = png

        assert {w, h} == {expected, expected}
      end
    end

    test "the page points at the manifest and at a large icon", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ ~s(rel="manifest")
      assert html =~ "/icon-192.png"
    end
  end

  # The test that was missing through three PRs. The others opened the file on
  # disk and asked for `/favicon.ico` — the canonical path, which works. A
  # browser never asks for that one: it asks for what the page declares, and
  # every one of those answered 404 because `phx.digest` renames the file and
  # `Plug.Static`'s `:only` matches the first segment exactly.
  #
  # So this asserts the address, not the file. Checking the bytes is not
  # checking that anyone can reach them.
  describe "the addresses the page actually declares" do
    test "every icon the head points at is served", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      declared =
        Regex.scan(~r{(?:href|content)="(/(?:favicon|icon-|apple-touch)[^"]*)"}, html,
          capture: :all_but_first
        )
        |> List.flatten()
        |> Enum.uniq()

      assert length(declared) >= 4, "the head stopped declaring icons"

      for path <- declared do
        # The query string is `phx.digest`'s cache buster, not part of the file.
        clean = path |> String.split("?") |> List.first()

        assert %{status: 200} = build_conn() |> get(clean),
               "#{path} is declared in the head and does not answer 200"
      end
    end

    test "the manifest it points at is served too", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      [path] =
        Regex.run(~r{rel="manifest" href="([^"]*)"}, html, capture: :all_but_first)

      assert %{status: 200} = build_conn() |> get(String.split(path, "?") |> List.first())
    end
  end

  # The test above passes in dev for the wrong reason: `phx.digest` does not run
  # here, so the head declares `/favicon.ico` and that path was never broken.
  # The defect only exists once the files are renamed, which is a property of
  # the build, not of the code — so this asks the question directly.
  describe "a digested filename" do
    setup do
      # A file with the shape `phx.digest` produces: same stem, hash, same
      # extension. It shares no exact name with anything in `static_paths/0`.
      path = Path.join([File.cwd!(), "priv/static", "favicon-deadbeef0123456789.ico"])
      File.write!(path, read(@ico))
      on_exit(fn -> File.rm(path) end)
      :ok
    end

    test "is served, because :only alone would refuse it" do
      assert %{status: 200} = build_conn() |> get("/favicon-deadbeef0123456789.ico")
    end

    test "and a name outside the prefixes still is not" do
      path = Path.join([File.cwd!(), "priv/static", "segredo-deadbeef.ico"])
      File.write!(path, read(@ico))
      on_exit(fn -> File.rm(path) end)

      assert %{status: 404} = build_conn() |> get("/segredo-deadbeef.ico")
    end
  end

  # Whoever adds the next root-level static file will not remember this, and the
  # symptom — an icon that answers 404 only in production — took three PRs to
  # find the first time.
  test "every root file in static_paths has a prefix that can serve it digested" do
    arquivos = Enum.filter(BlogoWeb.static_paths(), &String.contains?(&1, "."))

    for arquivo <- arquivos do
      stem = arquivo |> Path.rootname()

      assert Enum.any?(BlogoWeb.static_prefixes(), &String.starts_with?(stem, &1)),
             "#{arquivo} is served at its plain name but would 404 once digested"
    end
  end
end
