defmodule BlogoWeb.BlocksTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]

  alias BlogoWeb.Blocks

  defp inline(text), do: text |> Blocks.inline() |> Phoenix.HTML.safe_to_string()

  defp render(blocks) do
    assigns = %{blocks: blocks}
    rendered_to_string(~H"<Blocks.render_blocks blocks={@blocks} />")
  end

  describe "inline links" do
    test "a link in running text is an anchor to the address" do
      assert inline("Veja o [OpenStreetMap](https://www.openstreetmap.org).") ==
               ~s(Veja o <a href="https://www.openstreetmap.org" rel="noopener">OpenStreetMap</a>.)
    end

    test "an asterisk or underscore inside the address does not start emphasis" do
      html = inline("Um [link](https://x.com/a*b*c) e *isto*.")
      assert html =~ ~s(href="https://x.com/a*b*c")
      assert html =~ "<em>isto</em>"
      refute html =~ "<em>b</em>"
    end

    test "emphasis inside the link text still applies" do
      assert inline("[**Godot**](https://godotengine.org)") =~ "<b>Godot</b></a>"
    end

    test "a site-relative link carries no rel" do
      assert inline("[tag](/tag/godot)") == ~s(<a href="/tag/godot">tag</a>)
    end
  end

  describe "source" do
    test "shows its description once, never again as a margin note" do
      html =
        render([
          %{
            "type" => "source",
            "url" => "https://exemplo.com",
            "title" => "Skill",
            "note" => "Passo a passo único."
          }
        ])

      assert length(String.split(html, "Passo a passo único.")) == 2
      refute html =~ "mnote"
    end
  end
end
