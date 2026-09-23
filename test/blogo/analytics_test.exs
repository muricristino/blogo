defmodule Blogo.AnalyticsTest do
  @moduledoc """
  The panel is read as fact, so these cases are mostly about what the context
  refuses to say: no average without reads, no delta without a previous period,
  no percentage out of zero.
  """
  use Blogo.DataCase, async: true

  alias Blogo.Analytics
  alias Blogo.Fixtures

  defp read(post, attrs \\ %{}) do
    {:ok, read} =
      Analytics.record_read(
        post.id,
        Map.merge(%{depth: 50, seconds: 60, source: "direto", day: Date.utc_today()}, attrs)
      )

    read
  end

  describe "classificar a origem" do
    test "sem referenciador é direto" do
      assert Analytics.classify(nil) == "direto"
      assert Analytics.classify("") == "direto"
    end

    test "buscadores" do
      assert Analytics.classify("https://www.google.com/search?q=x") == "busca"
      assert Analytics.classify("https://duckduckgo.com/") == "busca"
      assert Analytics.classify("https://br.search.yahoo.com/") == "busca"
    end

    test "redes" do
      assert Analytics.classify("https://www.linkedin.com/feed/") == "redes"
      assert Analytics.classify("https://news.ycombinator.com/item?id=1") == "redes"
      assert Analytics.classify("https://t.co/abc") == "redes"
    end

    # Someone arriving from the index is not "outros", and calling it direct
    # would inflate the one number that says whether search is working.
    test "o próprio site é interno" do
      assert Analytics.classify("https://blogo.dev/", nil, "blogo.dev") == "interno"
    end

    test "utm_source ganha do referenciador" do
      assert Analytics.classify("https://www.google.com/", "newsletter") == "newsletter"
    end

    test "o que não se reconhece é outros, não um chute" do
      assert Analytics.classify("https://algumsite.example/post") == "outros"
    end
  end

  describe "o que chega do navegador é limitado" do
    setup do
      %{post: Fixtures.post()}
    end

    test "profundidade impossível é cortada em 100", %{post: post} do
      assert read(post, %{depth: 4000}).depth == 100
    end

    test "profundidade negativa vira zero", %{post: post} do
      assert read(post, %{depth: -5}).depth == 0
    end

    test "uma aba esquecida não vira horas de leitura", %{post: post} do
      assert read(post, %{seconds: 86_400}).seconds == Blogo.Analytics.Read.max_seconds()
    end

    test "origem inventada é recusada", %{post: post} do
      assert {:error, changeset} =
               Analytics.record_read(post.id, %{
                 depth: 10,
                 seconds: 10,
                 source: "inventada",
                 day: Date.utc_today()
               })

      assert "is invalid" in errors_on(changeset).source
    end
  end

  describe "totais" do
    setup do
      %{post: Fixtures.post(), range: Analytics.window(30)}
    end

    # Zero reads is not "zero per cent finished it" and not "zero seconds on
    # the page" — those are numbers nobody measured.
    test "sem leituras não há média nem taxa", %{range: range} do
      assert %{reads: 0, completion: nil, avg_seconds: nil} = Analytics.totals(range)
    end

    test "a taxa de conclusão conta quem passou do limiar", %{post: post, range: range} do
      read(post, %{depth: 95})
      read(post, %{depth: 90})
      read(post, %{depth: 89})
      read(post, %{depth: 10})

      assert %{reads: 4, completion: 50} = Analytics.totals(range)
    end

    test "o tempo médio é dos segundos medidos", %{post: post, range: range} do
      read(post, %{seconds: 60})
      read(post, %{seconds: 120})

      assert %{avg_seconds: 90} = Analytics.totals(range)
    end

    test "leituras fora da janela não entram", %{post: post} do
      read(post, %{day: Date.add(Date.utc_today(), -40)})

      assert %{reads: 0} = Analytics.totals(Analytics.window(30))
      assert %{reads: 1} = Analytics.totals(Analytics.window(90))
    end
  end

  describe "leituras por dia" do
    test "um dia sem leitura é zero, não um buraco" do
      post = Fixtures.post()
      read(post, %{day: Date.utc_today()})

      series = Analytics.daily(Analytics.window(7))

      assert length(series) == 7
      assert Enum.all?(series, &is_integer(&1.count))
      assert List.last(series).count == 1
      assert Enum.take(series, 6) |> Enum.all?(&(&1.count == 0))
    end
  end

  describe "origem das leituras" do
    test "soma cem por cento e vem ordenada" do
      post = Fixtures.post()
      for _ <- 1..6, do: read(post, %{source: "busca"})
      for _ <- 1..3, do: read(post, %{source: "redes"})
      read(post, %{source: "direto"})

      assert [busca, redes, direto] = Analytics.sources(Analytics.window(30))
      assert %{source: "busca", count: 6, pct: 60} = busca
      assert %{source: "redes", pct: 30} = redes
      assert %{source: "direto", pct: 10} = direto
    end
  end

  describe "até onde leem" do
    test "sem leituras a curva não existe" do
      assert Analytics.depth_curve(Analytics.window(30)) == []
    end

    test "começa em 100 e cai" do
      post = Fixtures.post()
      read(post, %{depth: 100})
      read(post, %{depth: 50})
      read(post, %{depth: 20})
      read(post, %{depth: 10})

      curve = Analytics.depth_curve(Analytics.window(30))

      assert List.first(curve) == %{depth: 0, pct: 100}
      assert Enum.find(curve, &(&1.depth == 50)).pct == 50
      assert List.last(curve) == %{depth: 90, pct: 25}
    end

    # Two numbers for the same fact on one screen have to agree. The curve used
    # to end at literal 100% scroll — touching the footer — so it showed 3%
    # beside a completion card reading 25%.
    test "o fim da curva é exatamente a taxa de conclusão" do
      post = Fixtures.post()
      read(post, %{depth: 95})
      read(post, %{depth: 92})
      read(post, %{depth: 40})
      read(post, %{depth: 10})

      range = Analytics.window(30)
      curve = Analytics.depth_curve(range)

      assert List.last(curve).pct == Analytics.totals(range).completion
    end

    test "a maior queda é nomeada" do
      post = Fixtures.post()
      for _ <- 1..9, do: read(post, %{depth: 15})
      read(post, %{depth: 100})

      curve = Analytics.depth_curve(Analytics.window(30))
      assert %{from: 10, to: 20, drop: 90} = Analytics.steepest_drop(curve)
    end
  end

  describe "por publicação" do
    test "um post sem leitura fica de fora, para o chamador decidir" do
      lido = Fixtures.post()
      _nao_lido = Fixtures.post()
      read(lido, %{depth: 95})

      by_post = Analytics.by_post(Analytics.window(30))

      assert %{reads: 1, completion: 100} = by_post[lido.id]
      assert map_size(by_post) == 1
    end
  end

  describe "janela anterior" do
    test "tem o mesmo tamanho e termina onde a atual começa" do
      {from, _to} = Analytics.window(7)
      {prev_from, prev_to} = Analytics.previous_window(7)

      assert Date.diff(prev_to, prev_from) == 6
      assert Date.add(prev_to, 1) == from
    end

    test "não existe comparação para tudo" do
      assert Analytics.previous_window(:all) == nil
    end
  end

  describe "a fila" do
    test "rascunho recente não está parado" do
      Fixtures.post(%{status: "draft", hero: nil})

      refute Enum.any?(Analytics.queue(), &(&1.kind == :stalled))
    end

    test "rascunho velho aparece, com link para o mais antigo" do
      post = Fixtures.post(%{status: "draft", hero: nil})

      # updated_at é gerenciado pelo Ecto, então o envelhecimento é feito no
      # banco — é o mesmo caminho que a consulta lê.
      Blogo.Repo.update_all(
        from(p in Blogo.Content.Post, where: p.id == ^post.id),
        set: [updated_at: DateTime.add(DateTime.utc_now(), -40 * 86_400, :second)]
      )

      assert item = Enum.find(Analytics.queue(), &(&1.kind == :stalled))
      assert item.href == "/editor/#{post.id}"
    end

    test "link interno para um artigo que não existe é apontado" do
      Fixtures.post(%{
        status: "published",
        title: "Com link quebrado",
        body: %{
          "blocks" => [
            %{"type" => "text", "paragraphs" => ["Veja [isto](/nao-existe) e mais nada."]}
          ]
        }
      })

      assert item = Enum.find(Analytics.queue(), &(&1.kind == :broken_link))
      assert item.text =~ "nao-existe"
    end

    test "link interno para um artigo publicado não é quebrado" do
      alvo = Fixtures.post(%{status: "published"})

      Fixtures.post(%{
        status: "published",
        body: %{
          "blocks" => [
            %{"type" => "text", "paragraphs" => ["Veja [isto](/#{alvo.slug})."]}
          ]
        }
      })

      refute Enum.any?(Analytics.queue(), &(&1.kind == :broken_link))
    end

    test "link externo não é checado aqui" do
      Fixtures.post(%{
        status: "published",
        body: %{
          "blocks" => [
            %{"type" => "text", "paragraphs" => ["Veja [isto](https://exemplo.com/x)."]}
          ]
        }
      })

      refute Enum.any?(Analytics.queue(), &(&1.kind == :broken_link))
    end
  end

  describe "medindo?" do
    test "distingue não ter leitor de não estar medindo" do
      refute Analytics.measuring?()

      read(Fixtures.post())

      assert Analytics.measuring?()
      assert Analytics.collecting_since() == Date.utc_today()
    end
  end
end
