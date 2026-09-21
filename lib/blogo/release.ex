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
  Loads the seed files when the database has no posts yet.

  Guarded on emptiness rather than on a flag: the seeds upsert by slug, so on a
  database with content they would overwrite edits made in production. On an
  empty one there is nothing to lose, and a fresh install comes up with
  something to read instead of an empty index.
  """
  def seed_if_empty do
    load_app()

    {:ok, empty?, _} =
      Ecto.Migrator.with_repo(Blogo.Repo, fn repo ->
        repo.aggregate(Blogo.Content.Post, :count) == 0
      end)

    if empty?, do: seed(), else: :ok
  end

  @doc """
  Loads the seed files unconditionally. Prefer `seed_if_empty/0` on boot.
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
