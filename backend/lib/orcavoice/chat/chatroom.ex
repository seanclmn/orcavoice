defmodule Orcavoice.Chat.Chatroom do
  use Orcavoice.Schema

  alias Orcavoice.Accounts.User

  @default_max_participants 50
  @max_participants_limit 1_000

  schema "chatrooms" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :is_private, :boolean, default: false
    field :max_participants, :integer, default: @default_max_participants

    belongs_to :owner, User

    timestamps()
  end

  @doc false
  def changeset(chatroom, attrs) do
    chatroom
    |> cast(attrs, [:name, :slug, :description, :is_private, :max_participants])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> maybe_generate_slug()
    |> validate_required([:slug])
    |> validate_length(:slug, min: 1, max: 100)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "only lowercase letters, numbers and single dashes"
    )
    |> validate_length(:description, max: 1_000)
    |> validate_number(:max_participants,
      greater_than: 0,
      less_than_or_equal_to: @max_participants_limit
    )
    |> unique_constraint(:slug)
    |> check_constraint(:max_participants, name: :max_participants_in_range)
    |> foreign_key_constraint(:owner_id)
  end

  defp maybe_generate_slug(changeset) do
    case {get_field(changeset, :slug), get_change(changeset, :name)} do
      {nil, name} when is_binary(name) -> put_change(changeset, :slug, slugify(name))
      _ -> changeset
    end
  end

  @doc "Turns a room name into a URL-safe slug."
  def slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 100)
  end
end
