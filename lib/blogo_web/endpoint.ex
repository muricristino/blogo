defmodule BlogoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :blogo

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_blogo_key",
    signing_salt: "yWmW1m47",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  # `:only` matches the first path segment **exactly**, and for a file at the
  # root of priv/static that segment is the whole filename. `phx.digest` renames
  # those files, so `~p"/favicon.ico"` resolves to `favicon-<digest>.ico` and
  # this plug then refuses precisely that name — every icon the page declared
  # answered 404 while `/favicon.ico` answered 200. `assets/…` escaped it
  # because there the first segment is `assets` and everything below passes.
  #
  # `:only_matching` matches by prefix, which is what a digested filename needs.
  plug Plug.Static,
    at: "/",
    from: :blogo,
    gzip: false,
    only: BlogoWeb.static_paths(),
    only_matching: BlogoWeb.static_prefixes()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :blogo
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug BlogoWeb.Router
end
