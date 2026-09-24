defmodule Blogo.Content.SiteTest do
  @moduledoc """
  blogo is self-hosted, so the name in the header belongs to whoever installed
  it. These check that it is really configuration — read from the database,
  written back, and never a value someone has to redeploy to change.
  """
  use Blogo.DataCase

  alias Blogo.Content
  alias Blogo.Content.Site

  describe "a fresh install" do
    test "has a site struct rather than nil, so no page has to guard" do
      assert %Site{} = Content.the_site()
    end

    test "is reported as unnamed" do
      assert Site.unnamed?(Content.the_site())
    end

    # Falling back to the host is a fact about where the install lives. A
    # default like "blogo" would be a name nobody chose, displayed as if they had.
    test "falls back to its own hostname, not to an invented name" do
      name = Content.site_name(Content.the_site())

      refute name == "blogo"
      assert name == BlogoWeb.Endpoint.url() |> URI.parse() |> Map.get(:host)
    end
  end

  describe "naming it" do
    test "the name reaches the database, not just the struct in hand" do
      {:ok, _} = Content.update_site(%{"name" => "Diário de bordo"})

      assert Content.the_site().name == "Diário de bordo"
      assert Content.site_name(Content.the_site()) == "Diário de bordo"
      refute Site.unnamed?(Content.the_site())
    end

    test "a second save updates the same row instead of making another" do
      {:ok, _} = Content.update_site(%{"name" => "Primeiro"})
      {:ok, _} = Content.update_site(%{"name" => "Segundo"})

      assert Content.the_site().name == "Segundo"
      assert Repo.aggregate(Site, :count) == 1
    end

    test "blanking the name puts the install back to unnamed" do
      {:ok, _} = Content.update_site(%{"name" => "Algum nome"})
      {:ok, _} = Content.update_site(%{"name" => "   "})

      assert Site.unnamed?(Content.the_site())
    end

    test "the description is kept and bounded" do
      {:ok, _} = Content.update_site(%{"name" => "X", "description" => "Uma linha."})
      assert Content.the_site().description == "Uma linha."

      assert {:error, changeset} =
               Content.update_site(%{"description" => String.duplicate("a", 161)})

      assert changeset.errors[:description]
    end
  end
end
