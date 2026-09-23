defmodule BlogoWeb.Router do
  use BlogoWeb, :router

  import BlogoWeb.AdminAuth, only: [require_admin: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BlogoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # The editor is a separate stack: it has its own layout and it is the only
  # place that writes, so the guard sits on the pipeline rather than on each
  # route where one could be forgotten.
  pipeline :admin do
    plug :put_root_layout, html: {BlogoWeb.Layouts, :root}
    plug :require_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BlogoWeb do
    pipe_through :browser

    get "/", PostController, :index
    get "/sitemap.xml", SitemapController, :index
    get "/robots.txt", SitemapController, :robots
    get "/autor/:slug", AuthorController, :show
    get "/imagem/:slug", CardController, :show

    get "/entrar", SessionController, :new
    post "/entrar", SessionController, :create
    delete "/sair", SessionController, :delete
  end

  scope "/editor", BlogoWeb do
    pipe_through [:browser, :admin]

    live_session :editor,
      on_mount: {BlogoWeb.AdminAuth, :ensure_admin},
      layout: {BlogoWeb.Layouts, :editor} do
      live "/", EditorLive.Index, :index
      live "/:id", EditorLive.Edit, :edit
    end

    get "/:id/previa", PreviewController, :show
  end

  # Last, because it matches any single segment and would otherwise swallow
  # /entrar and /editor.
  scope "/", BlogoWeb do
    pipe_through :browser

    get "/:slug", PostController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", BlogoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:blogo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BlogoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
