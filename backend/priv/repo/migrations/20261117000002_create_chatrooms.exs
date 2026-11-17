defmodule Orcavoice.Repo.Migrations.CreateChatrooms do
  use Ecto.Migration

  def change do
    create table(:chatrooms) do
      add :name, :string, size: 100, null: false
      add :slug, :citext, null: false
      add :description, :text
      add :is_private, :boolean, null: false, default: false
      add :max_participants, :integer, null: false, default: 50

      # Keep the room if its owner is deleted; ownership can be reassigned.
      add :owner_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:chatrooms, [:slug])
    create index(:chatrooms, [:owner_id])

    # Partial index for the public room listing (keyset-paginated, newest first).
    create index(:chatrooms, ["inserted_at DESC", "id DESC"],
             where: "is_private = false",
             name: :chatrooms_public_listing_index
           )

    create constraint(:chatrooms, :max_participants_in_range,
             check: "max_participants > 0 AND max_participants <= 1000"
           )
  end
end
