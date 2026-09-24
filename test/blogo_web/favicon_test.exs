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
end
