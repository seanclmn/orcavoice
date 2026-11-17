import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :orcavoice, Orcavoice.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5434,
  database: "orcavoice_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :orcavoice, OrcavoiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "bcUqpSsW2RkBfwNYpk3Y4jmL2To4P4zquzcI+5t0Q7prrtOfE6oMPdr5jWt7m1Pn",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Lets requests identify themselves with an `x-user-id` header until real
# authentication exists. NEVER enable this in production.
config :orcavoice, :header_auth, true

# Don't call LiveKit from tests; set counts with Occupancy.put_counts/1.
config :orcavoice, Orcavoice.Chat.Occupancy, poll: false

config :orcavoice, Orcavoice.LiveKit,
  url: "http://localhost:0",
  public_url: "ws://livekit.test",
  api_key: "test",
  api_secret: "test"

config :orcavoice, :livekit_api, Orcavoice.LiveKitFake
