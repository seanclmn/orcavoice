defmodule Orcavoice.Repo do
  use Ecto.Repo,
    otp_app: :orcavoice,
    adapter: Ecto.Adapters.Postgres
end
