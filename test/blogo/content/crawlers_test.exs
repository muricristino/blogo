defmodule Blogo.Content.CrawlersTest do
  @moduledoc """
  The point of this feature is that the decision is the installer's, so these
  cases check that the file says what was chosen — and that it keeps saying it
  when the choice changes.
  """
  use Blogo.DataCase, async: true

  alias Blogo.Content
  alias Blogo.Content.{Crawlers, Site}

  @base "https://exemplo.test"

  defp robots(policy) do
    Crawlers.robots_txt(%Site{id: 1, ai_crawlers: policy}, @base)
  end

  # A group is "User-agent: X" followed by its one rule, so the rule for an
  # agent is the line right after it.
  defp rule_for(body, agent) do
    body
    |> String.split("\n")
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value(fn
      ["User-agent: " <> ^agent, rule] -> rule
      _ -> nil
    end)
  end

  describe "who decides" do
    test "an install that never answered is treated as citation only" do
      assert Crawlers.policy(%Site{id: 1}) == "citation"
      refute Crawlers.chosen?(%Site{id: 1})
    end

    test "choosing the same thing as the default still counts as choosing" do
      assert Crawlers.chosen?(%Site{id: 1, ai_crawlers: "citation"})
    end

    test "the database keeps the choice and the changeset refuses an invented one" do
      {:ok, _} = Content.update_site(%{"ai_crawlers" => "none"})
      assert Content.the_site().ai_crawlers == "none"

      assert {:error, changeset} = Content.update_site(%{"ai_crawlers" => "talvez"})
      assert changeset.errors[:ai_crawlers]
      assert Content.the_site().ai_crawlers == "none"
    end

    test "the four options the panel offers are the four the column accepts" do
      assert Enum.map(Crawlers.options(), & &1.value) |> Enum.sort() ==
               Enum.sort(Crawlers.policies())
    end

    test "every option explains what it does, because nobody knows these agents" do
      for option <- Crawlers.options() do
        assert String.length(option.description) > 60
      end
    end
  end

  describe "the generated robots.txt" do
    test "citation only: the trainers are refused and the answerers are allowed" do
      body = robots("citation")

      assert rule_for(body, "GPTBot") == "Disallow: /"
      assert rule_for(body, "CCBot") == "Disallow: /"
      assert rule_for(body, "Google-Extended") == "Disallow: /"
      assert rule_for(body, "OAI-SearchBot") == "Allow: /"
      assert rule_for(body, "PerplexityBot") == "Allow: /"
      assert rule_for(body, "Claude-User") == "Allow: /"
    end

    test "both: the same agents, now with yes beside them" do
      body = robots("both")

      assert rule_for(body, "GPTBot") == "Allow: /"
      assert rule_for(body, "ClaudeBot") == "Allow: /"
      assert rule_for(body, "OAI-SearchBot") == "Allow: /"
    end

    test "training only: in the model, out of the answers" do
      body = robots("training")

      assert rule_for(body, "GPTBot") == "Allow: /"
      assert rule_for(body, "ChatGPT-User") == "Disallow: /"
      assert rule_for(body, "PerplexityBot") == "Disallow: /"
    end

    test "none: every known AI agent is refused, and llms.txt is not announced" do
      body = robots("none")

      for agent <- Crawlers.training_agents() ++ Crawlers.citation_agents() do
        assert rule_for(body, agent) == "Disallow: /", "#{agent} deveria estar barrado"
      end

      refute body =~ "llms.txt"
    end

    # The whole point of naming them: `User-agent: *` already allowed everyone,
    # so a file that only carried the wildcard was a decision nobody made.
    test "each agent is named even when the answer is yes" do
      body = robots("both")

      for agent <- Crawlers.training_agents() ++ Crawlers.citation_agents() do
        assert body =~ "User-agent: #{agent}"
      end
    end

    test "a human reader is told where the choice lives and what each group is" do
      body = robots("citation")

      assert body =~ "painel"
      assert body =~ "Treino de modelo: não"
      assert body =~ "Citação em resposta de IA: sim"
    end

    # Refusing Googlebot to keep Gemini out means leaving Google's search
    # results. The file says so rather than pretending the choice reaches them.
    test "no rule touches the agents that also serve a search engine" do
      body = robots("none")

      refute rule_for(body, "Googlebot")
      refute rule_for(body, "Bingbot")
      refute rule_for(body, "Applebot")
      refute rule_for(body, "Amazonbot")
      assert body =~ "Gemini lê com o Googlebot"
    end

    test "the sitemap and the map for models are still pointed at" do
      body = robots("citation")

      assert body =~ "Sitemap: #{@base}/sitemap.xml"
      assert body =~ "#{@base}/llms.txt"
    end

    test "the crawler that only reads the wildcard still gets everything" do
      assert robots("none") =~ "User-agent: *\nAllow: /"
    end
  end
end
