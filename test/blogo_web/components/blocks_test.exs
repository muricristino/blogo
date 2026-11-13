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
