{:ok, _} = Orcavoice.LiveKitFake.start_link([])
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Orcavoice.Repo, :manual)
