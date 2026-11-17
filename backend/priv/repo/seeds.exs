# Dev seed data. Safe to run repeatedly (existing records are reused):
#
#     mix run priv/repo/seeds.exs

alias Orcavoice.{Accounts, Chat}

find_or_create_user = fn attrs ->
  Accounts.get_user_by_username(attrs.username) ||
    (
      {:ok, user} = Accounts.create_user(attrs)
      user
    )
end

find_or_create_room = fn owner, attrs ->
  slug = Chat.Chatroom.slugify(attrs.name)

  Chat.get_chatroom_by_slug(slug) ||
    (
      {:ok, room} = Chat.create_chatroom(owner, attrs)
      room
    )
end

users =
  [
    %{username: "orca", email: "orca@example.com", display_name: "Orca"},
    %{username: "beluga", email: "beluga@example.com", display_name: "Beluga"},
    %{username: "narwhal", email: "narwhal@example.com", display_name: "Narwhal"}
  ]
  |> Enum.map(find_or_create_user)
  |> Map.new(&{&1.username, &1})

rooms = [
  {"orca", %{name: "Lobby", description: "Say hi and hang out.", max_participants: 200}},
  {"orca", %{name: "Late Night Talk", description: "For the night owls (and night whales)."}},
  {"beluga",
   %{name: "Music Production", description: "Share beats, get feedback.", max_participants: 25}},
  {"beluga", %{name: "Gaming", description: "Squad up and chat while you play."}},
  {"narwhal",
   %{
     name: "Study Hall",
     description: "Quiet co-working. Mics mostly muted.",
     max_participants: 100
   }},
  {"narwhal", %{name: "Language Exchange", description: "Practice speaking with natives."}},
  {"orca",
   %{name: "Book Club", description: "This month: deep-sea fiction.", max_participants: 12}},
  {"narwhal", %{name: "Mods Only", description: "Private moderator room.", is_private: true}}
]

for {owner, attrs} <- rooms, do: find_or_create_room.(users[owner], attrs)

IO.puts("Seeded #{map_size(users)} users and #{length(rooms)} chatrooms (1 private).")
