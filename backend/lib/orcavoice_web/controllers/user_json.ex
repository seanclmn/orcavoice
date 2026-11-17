defmodule OrcavoiceWeb.UserJSON do
  alias Orcavoice.Accounts.User

  @doc "Public profile, safe to show anyone. Never includes email."
  def show(%{user: user}), do: %{data: public(user)}

  @doc "The signed-in user's own view, including private fields."
  def me(%{user: user}), do: %{data: Map.put(public(user), :email, user.email)}

  def public(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      inserted_at: user.inserted_at
    }
  end
end
