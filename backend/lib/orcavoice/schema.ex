defmodule Orcavoice.Schema do
  @moduledoc """
  Shared schema defaults: UUID primary/foreign keys and UTC timestamps.

      use Orcavoice.Schema
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime]
    end
  end
end
