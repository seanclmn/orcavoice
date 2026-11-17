# OrcaVoice

A voice chat app built to eventually handle about 1M concurrent users.

## Layout
- `backend/`: Phoenix 1.7 JSON API (Elixir 1.18, OTP 27). App: `:orcavoice`, modules `Orcavoice.*` / `OrcavoiceWeb.*`
- `frontend/`: React + TypeScript (entry: `src/App.tsx`)
- `livekit/`: LiveKit SFU config (handles voice media)
- `docker-compose.yml`: Postgres 17 + LiveKit

## Local dev
- `docker compose up -d`: Postgres on **localhost:5434** (postgres/postgres, db `orcavoice_dev`); LiveKit on 7880 (signaling), 7881 (TCP), 7882/udp (media)
- `cd backend && mix setup`: install deps, create the DB, migrate, seed
- `mix phx.server`: API on http://127.0.0.1:4000
- `mix test`: run the tests (creates and migrates the test DB)

## Conventions
- Ecto + Postgres; timestamps are `:utc_datetime`
- Put business logic in contexts under `lib/orcavoice/`; keep the web layer thin
- JSON only (no HTML or LiveView views)
- Design for scale: no per-user hot rows, and keep ephemeral state (presence, who's in a room) out of Postgres (use Phoenix.Presence / LiveKit)
- Voice media goes through LiveKit; Phoenix handles auth, rooms and signaling metadata
