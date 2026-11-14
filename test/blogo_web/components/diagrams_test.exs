defmodule BlogoWeb.DiagramsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]

  alias BlogoWeb.Diagrams

  @steps [
    %{"label" => "OSM", "note" => "prédios e altura"},
    %{"label" => "Street View", "note" => "print a cada 30 m"},
    %{"label" => "Blender", "note" => "por script", "accent" => true},
    %{"label" => "Godot", "note" => "640×480"},
    %{"label" => "prints", "note" => "conferência"}
  ]

  defp fluxo(data, orientation \\ "h") do
    assigns = %{data: data, orientation: orientation}

    rendered_to_string(~H"""
    <Diagrams.diagram form="fluxo" data={@data} orientation={@orientation} />
    """)
  end

  defp view_box(html) do
    [_, w, h] = Regex.run(~r/viewBox="0 0 (\d+) (\d+)"/, html)
    {String.to_integer(w), String.to_integer(h)}
  end

  defp widths(html) do
    ~r/<rect[^>]*width="(\d+)"/
    |> Regex.scan(html)
    |> Enum.map(fn [_, w] -> String.to_integer(w) end)
  end

  test "a box is wider than its longest line, so the words stay inside" do
    html = fluxo(%{"steps" => @steps})
    [osm, street | _] = widths(html)

    assert street >= String.length("print a cada 30 m") * 5.7
    assert osm >= String.length("prédios e altura") * 5.7
  end

  test "the boxes fit inside the drawing" do
    html = fluxo(%{"steps" => @steps})
    {width, _} = view_box(html)

    xs =
      ~r/<rect[^>]*x="(-?\d+)"/
      |> Regex.scan(html)
      |> Enum.map(fn [_, x] -> String.to_integer(x) end)

    assert Enum.min(xs) >= 0
    assert List.last(xs) + List.last(widths(html)) <= width
  end

  test "without a branch the drawing is only as tall as its boxes" do
    {_, height} = view_box(fluxo(%{"steps" => @steps}))
    assert height < 60
  end

  test "with a branch it keeps the room the branch is drawn in" do
    {_, height} =
      view_box(fluxo(%{"steps" => @steps, "branch" => %{"x" => 200, "label" => "fila"}}))

    assert height == 150
  end

  test "stacked, each step is a row of its own" do
    html = fluxo(%{"steps" => @steps}, "v")
    {width, height} = view_box(html)
    assert height > width
    assert html =~ "dg--v"
  end

  test "a flow of several steps without a branch stacks on a phone" do
    assert Diagrams.flow_stacks?(%{"steps" => @steps})
    refute Diagrams.flow_stacks?(%{"steps" => @steps, "branch" => %{"x" => 1}})
    refute Diagrams.flow_stacks?(%{"steps" => Enum.take(@steps, 2)})
    refute Diagrams.flow_stacks?(nil)
  end

  test "incomplete data draws nothing broken instead of raising" do
    assert fluxo(%{"steps" => [%{}, "lixo", %{"label" => 3}]}) =~ "<svg"
    assert fluxo(%{"steps" => "nada"}, "v") =~ "<svg"
  end
end
