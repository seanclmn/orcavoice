defmodule Orcavoice.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    # Case-insensitive text: "Alice" and "alice" collide on unique indexes
    # without needing lower() expression indexes.
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:users) do
      add :username, :citext, null: false
      add :email, :citext, null: false
      add :display_name, :string, size: 64
      add :avatar_url, :text

      timestamps()
    end

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
  end
end
