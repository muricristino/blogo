defmodule BlogoWeb.FootCreditTest do
  @moduledoc """
  The footer says who runs the blog. On an install where the site is named after
  the person — which is this one, and the case the project exists for — saying it
  twice is what came out of two correct halves meeting.
  """
  use ExUnit.Case, async: true

  import BlogoWeb.Layouts, only: [foot_credit: 2]

  defp author(name, city \\ nil), do: %{name: name, city: city}

  describe "when the site is named after the author" do
    test "the name is not repeated, and the place survives" do
      credit = foot_credit("Muri Cristino", author("Muri Cristino", "São Paulo"))

      assert credit == "Muri Cristino · São Paulo"
      refute credit =~ ~r/Muri Cristino.*Muri Cristino/
    end

    test "with no city there is nothing left to add" do
      assert foot_credit("Muri Cristino", author("Muri Cristino")) == "Muri Cristino"
    end

    # Someone types the site's name by hand in the panel; it will not always come
    # out with the same capitalisation or spacing as the author record.
    test "a difference of case or spacing is still the same name" do
      assert foot_credit("muri cristino", author("Muri Cristino")) == "muri cristino"
      assert foot_credit("Muri Cristino ", author("Muri Cristino")) == "Muri Cristino "
    end
  end

  describe "when they are different" do
    test "both are said, because both carry information" do
      credit = foot_credit("Notas de produção", author("Muri Cristino", "São Paulo"))

      assert credit =~ "Notas de produção"
      assert credit =~ "Muri Cristino"
      assert credit =~ "São Paulo"
    end
  end

  test "with no author at all it is just the site" do
    assert foot_credit("Notas de produção", nil) == "Notas de produção"
  end
end
