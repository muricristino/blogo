defmodule Blogo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BlogoWeb.Telemetry,
      Blogo.Repo,
      {DNSCluster, query: Application.get_env(:blogo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Blogo.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Blogo.Finch},
      # Start a worker by calling: Blogo.Worker.start_link(arg)
      # {Blogo.Worker, arg},
      # Start to serve requests, typically the last entry
      BlogoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Blogo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BlogoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
