defmodule Blogo.Content.Crawlers do
  @moduledoc """
  What a crawler that feeds a generative model may do with what is written
  here, and the `robots.txt` that says it.

  blogo is self-hosted, so this is not a decision the code gets to make: one
  person wants their writing inside every model, the next wants to be quoted
  and never trained on, and both are reasonable. The panel asks, this module
  answers, and `robots.txt` is generated from it — an install that never
  answers is treated as "citation only", said in words on the panel rather than
  hidden in a column default.

  ## Why the agents are named one by one

  `User-agent: *` already allows everything, which is how GPTBot and CCBot got
  in — by omission, not by choice. So the file names each known AI agent and
  writes `Allow` or `Disallow` beside it, even when the answer is yes. A reader
  of the file can then see what was decided instead of inferring it from a
  wildcard.

  ## Who no rule here can reach

  Gemini reads with Googlebot, Copilot with Bingbot, Siri and Spotlight with
  Applebot, Alexa with Amazonbot. Those are the same agents that index the site
  for their search engines, so refusing them means leaving search. They are
  deliberately absent from both lists, and `robots.txt` says so where somebody
  will read it.

  ## Where the rule lives

  Here, and nowhere else. Cloudflare sits in front of this site and its AI Crawl
  Control can block the same agents at the edge, which would mean two places
  disagreeing about one decision — and the edge would win silently, with the
  panel still claiming otherwise. The tunnel passes `/robots.txt` through from
  the app; Cloudflare's managed robots.txt and its AI blocking rules stay off.
  """

  alias Blogo.Content.Site

  @policies ~w(both citation training none)
  @default "citation"

  # Crawlers that collect in bulk to train a model. Google-Extended and
  # Applebot-Extended are training-only tokens: refusing them costs nothing in
  # search, which is exactly why they exist.
  @training_agents [
    "GPTBot",
    "ClaudeBot",
    "anthropic-ai",
    "Claude-Web",
    "Google-Extended",
    "Applebot-Extended",
    "CCBot",
    "meta-externalagent",
    "FacebookBot",
    "Bytespider",
    "PanguBot",
    "AI2Bot",
    "Ai2Bot-Dolma",
    "Diffbot",
    "Omgilibot",
    "omgili",
    "Webzio-Extended",
    "ImagesiftBot",
    "Timpibot",
    "cohere-ai",
    "cohere-training-data-crawler",
    "SemrushBot-OCOB"
  ]

  # Crawlers that fetch a page to answer a question now, with a link back. Only
  # agents whose single job is that: a dual-purpose one would take the site out
  # of a search engine along with the assistant.
  @citation_agents [
    "OAI-SearchBot",
    "ChatGPT-User",
    "Claude-User",
    "Claude-SearchBot",
    "PerplexityBot",
    "Perplexity-User",
    "MistralAI-User",
    "DuckAssistBot",
    "Meta-ExternalFetcher",
    "Google-CloudVertexBot",
    "YouBot"
  ]

  @doc "The four answers, as stored."
  def policies, do: @policies

  @doc "What an install that has not answered gets, and why it is that one."
  def default, do: @default

  def training_agents, do: @training_agents
  def citation_agents, do: @citation_agents

  @doc """
  The policy in force. An install that never chose gets the default rather than
  `nil`, so no caller has to guess.
  """
  def policy(%Site{ai_crawlers: chosen}) when chosen in @policies, do: chosen
  def policy(_site), do: @default

  @doc "Whether anybody actually chose, which the panel has to say out loud."
  def chosen?(%Site{ai_crawlers: chosen}), do: chosen in @policies
  def chosen?(_site), do: false

  def training?(policy), do: policy in ["both", "training"]
  def citation?(policy), do: policy in ["both", "citation"]

  @doc """
  The choices as the panel offers them, each with what it actually does. The
  wording is the interface's, so it is in the reader's language.
  """
  def options do
    [
      %{
        value: "both",
        label: "Treino e citação",
        description:
          "Pode ler para treinar modelo e pode citar em resposta. É o que o robots.txt " <>
            "permitia por omissão até agora."
      },
      %{
        value: "citation",
        label: "Só citação",
        description:
          "Pode ler para responder alguém agora, com link de volta. Não pode usar o texto " <>
            "para treinar. É o padrão: ser citado é o motivo de publicar, e treinar não " <>
            "devolve nada ao autor."
      },
      %{
        value: "training",
        label: "Só treino",
        description:
          "Pode entrar no treinamento e não deve buscar a página para responder na hora. " <>
            "Faz sentido para quem quer estar no modelo sem receber esse tráfego."
      },
      %{
        value: "none",
        label: "Nenhum dos dois",
        description:
          "Nenhum crawler de IA conhecido. O /llms.txt sai do ar junto, porque um mapa " <>
            "escrito para modelo não combina com dizer que nenhum pode ler."
      }
    ]
  end

  @doc "One line describing a policy, for `llms.txt` and for the panel."
  def summary(policy) do
    case policy do
      "both" -> "Treinar: permitido. Citar em resposta: permitido, com link."
      "citation" -> "Treinar: não permitido. Citar em resposta: permitido, com link."
      "training" -> "Treinar: permitido. Buscar a página para responder: não permitido."
      "none" -> "Nenhum crawler de IA é permitido nesta instalação."
    end
  end

  @doc """
  The whole `robots.txt`, generated from the policy.

  `llms.txt` is announced as a comment: robots.txt has no directive for it, and
  a comment is read by the person debugging this file, which is who needs it.
  """
  def robots_txt(site, base_url) do
    policy = policy(site)

    ([
       "# Gerado pelo blogo. A escolha sobre crawler de IA está no painel,",
       "# em “O que crawler de IA pode fazer” — não edite este arquivo à mão.",
       "",
       "User-agent: *",
       "Allow: /",
       "",
       "Sitemap: #{base_url}/sitemap.xml"
     ] ++
       llms_comment(policy, base_url) ++
       group(
         "Treino de modelo",
         @training_agents,
         training?(policy),
         "o texto pode entrar no treinamento",
         "o texto não deve entrar em treinamento"
       ) ++
       group(
         "Citação em resposta de IA",
         @citation_agents,
         citation?(policy),
         "pode ler a página para responder alguém, com link de volta",
         "não deve ler a página para responder"
       ) ++
       [
         "",
         "# Gemini lê com o Googlebot, Copilot com o Bingbot, Siri e Spotlight com o",
         "# Applebot, Alexa com o Amazonbot. São os mesmos agentes da busca deles, então",
         "# nenhuma regra aqui os alcança sem tirar o blog da busca — por isso não estão",
         "# em nenhuma das listas acima.",
         ""
       ])
    |> Enum.join("\n")
  end

  defp llms_comment("none", _base_url), do: []

  defp llms_comment(_policy, base_url) do
    ["", "# Mapa do site para modelo generativo: #{base_url}/llms.txt"]
  end

  defp group(title, agents, allowed?, yes, no) do
    rule = if allowed?, do: "Allow: /", else: "Disallow: /"
    answer = if allowed?, do: "sim — #{yes}", else: "não — #{no}"

    ["", "# #{title}: #{answer}."] ++
      Enum.flat_map(agents, &["User-agent: #{&1}", rule])
  end
end
