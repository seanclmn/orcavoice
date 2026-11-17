defmodule Orcavoice.AccountsTest do
  use Orcavoice.DataCase, async: true

  import Orcavoice.AccountsFixtures

  alias Orcavoice.Accounts
  alias Orcavoice.Accounts.User

  describe "create_user/1" do
    test "creates a user with valid attrs" do
      assert {:ok, %User{} = user} =
               Accounts.create_user(%{username: "orca_fan", email: "orca@example.com"})

      assert user.username == "orca_fan"
      assert is_binary(user.id)
    end

    test "requires username and email" do
      assert {:error, changeset} = Accounts.create_user(%{})
      assert %{username: ["can't be blank"], email: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid username and email formats" do
      assert {:error, changeset} = Accounts.create_user(%{username: "a b", email: "nope"})
      errors = errors_on(changeset)
      assert "only letters, numbers and underscores" in errors.username
      assert "must be a valid email" in errors.email
    end

    test "username and email are unique case-insensitively" do
      user_fixture(username: "Orca", email: "Orca@Example.com")

      assert {:error, changeset} =
               Accounts.create_user(%{username: "orca", email: "other@example.com"})

      assert "has already been taken" in errors_on(changeset).username

      assert {:error, changeset} =
               Accounts.create_user(%{username: "other", email: "orca@example.com"})

      assert "has already been taken" in errors_on(changeset).email
    end
  end

  test "lookup by username ignores case" do
    user = user_fixture(username: "MixedCase")
    assert Accounts.get_user_by_username("mixedcase").id == user.id
  end

  test "update_user/2 updates fields" do
    user = user_fixture()
    assert {:ok, user} = Accounts.update_user(user, %{display_name: "New Name"})
    assert user.display_name == "New Name"
  end
end
