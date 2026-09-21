defmodule Blogo.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :blogo

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Loads the seed files. Run by hand, once, on a fresh install — never on boot,
  because the seeds upsert by slug and would overwrite anything edited in
  production.
  """
  def seed do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(Blogo.Repo, fn _repo ->
        for file <- ~w(seeds.exs seeds_extra.exs) do
          path = Application.app_dir(@app, "priv/repo/#{file}")
          if File.exists?(path), do: Code.eval_file(path)
        end
      end)
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
