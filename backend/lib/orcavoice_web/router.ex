defmodule OrcavoiceWeb.Router do
  use OrcavoiceWeb, :router

  import OrcavoiceWeb.Plugs.CurrentUser

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_current_user
  end

  pipeline :authenticated do
    plug :require_user
  end

  # Public: no signed-in user needed
  scope "/api", OrcavoiceWeb do
    pipe_through :api

    post "/users", UserController, :create
    get "/users/:id", UserController, :show
    get "/users/:id/chatrooms", UserController, :chatrooms

    get "/chatrooms", ChatroomController, :index
    get "/chatrooms/occupancy", ChatroomController, :occupancy
    get "/chatrooms/slug/:slug", ChatroomController, :show_by_slug
    get "/chatrooms/:id", ChatroomController, :show
  end

  # Server-to-server: LiveKit webhooks, authenticated by signature
  scope "/api/livekit", OrcavoiceWeb do
    post "/webhook", LiveKitWebhookController, :create
  end

  # Requires a signed-in user
  scope "/api", OrcavoiceWeb do
    pipe_through [:api, :authenticated]

    get "/me", UserController, :me
    patch "/me", UserController, :update_me

    post "/chatrooms", ChatroomController, :create
    post "/chatrooms/:id/token", ChatroomController, :token
    patch "/chatrooms/:id", ChatroomController, :update
    delete "/chatrooms/:id", ChatroomController, :delete
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:orcavoice, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: OrcavoiceWeb.Telemetry
    end
  end
end
