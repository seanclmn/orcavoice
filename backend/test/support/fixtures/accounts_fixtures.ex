defmodule Orcavoice.AccountsFixtures do
  def unique_username, do: "user_#{System.unique_integer([:positive])}"
  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{username: unique_username(), email: unique_email(), display_name: "Test"})
      |> Orcavoice.Accounts.create_user()

    user
  end
end
