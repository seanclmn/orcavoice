defmodule Orcavoice.Accounts.User do
  use Orcavoice.Schema

  schema "users" do
    field :username, :string
    field :email, :string
    field :display_name, :string
    field :avatar_url, :string

    has_many :owned_chatrooms, Orcavoice.Chat.Chatroom, foreign_key: :owner_id

    timestamps()
  end

  @username_format ~r/^[a-zA-Z0-9_]+$/
  @email_format ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :display_name, :avatar_url])
    |> validate_required([:username, :email])
    |> validate_length(:username, min: 3, max: 32)
    |> validate_format(:username, @username_format,
      message: "only letters, numbers and underscores"
    )
    |> validate_length(:email, max: 160)
    |> validate_format(:email, @email_format, message: "must be a valid email")
    |> validate_length(:display_name, max: 64)
    |> validate_length(:avatar_url, max: 2048)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end
end
