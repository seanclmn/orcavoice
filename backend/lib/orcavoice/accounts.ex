defmodule Orcavoice.Accounts do
  @moduledoc """
  User accounts.
  """

  alias Orcavoice.Repo
  alias Orcavoice.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

  @doc "Returns the user, or nil if not found or `id` is not a valid UUID."
  def get_user(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(User, uuid)
      :error -> nil
    end
  end

  def get_user_by_username(username) when is_binary(username),
    do: Repo.get_by(User, username: username)

  def get_user_by_email(email) when is_binary(email),
    do: Repo.get_by(User, email: email)

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user), do: Repo.delete(user)

  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)
end
