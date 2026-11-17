import { useState, type ReactNode } from 'react'
import { LiveKitRoom, RoomAudioRenderer } from '@livekit/components-react'
import type { Chatroom } from './api/chatrooms'
import { setCurrentUser, useCurrentUser } from './api/session'
import { useJoinVoice, type VoiceSession } from './api/voice'
import { ChatroomList } from './components/ChatroomList'
import { SignUpForm } from './components/SignUpForm'
import { VoiceRoom } from './components/VoiceRoom'

const DRAWER_ID = 'rooms-drawer'

interface ActiveVoice extends VoiceSession {
  room: Chatroom
}

function App() {
  const user = useCurrentUser()
  const [selectedRoom, setSelectedRoom] = useState<Chatroom | null>(null)
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [voice, setVoice] = useState<ActiveVoice | null>(null)
  const [voiceError, setVoiceError] = useState<string | null>(null)
  const joinVoice = useJoinVoice()

  const selectRoom = (room: Chatroom) => {
    setSelectedRoom(room)
    setDrawerOpen(false) // close the overlay on small screens
  }

  const join = (room: Chatroom) => {
    setVoiceError(null)
    joinVoice.mutate(room.id, {
      onSuccess: (session) => setVoice({ ...session, room }),
    })
  }

  const leave = () => setVoice(null)

  const signOut = () => {
    leave()
    setCurrentUser(null)
  }

  const inSelectedRoom = voice !== null && voice.room.id === selectedRoom?.id

  let content: ReactNode
  if (!selectedRoom) {
    content = <EmptyState />
  } else if (inSelectedRoom) {
    content = <VoiceRoom room={voice.room} speakerLimit={voice.speakerLimit} onLeave={leave} />
  } else {
    content = (
      <RoomDetails
        room={selectedRoom}
        signedIn={user !== null}
        inOtherRoom={voice !== null}
        joining={joinVoice.isPending && joinVoice.variables === selectedRoom.id}
        error={joinVoice.isError ? joinVoice.error.message : voiceError}
        onJoin={() => join(selectedRoom)}
      />
    )
  }

  const main = (
    <main className="flex flex-1 flex-col gap-4 p-4 sm:p-8">
      {voice && !inSelectedRoom && (
        <div role="status" className="alert alert-success alert-soft max-w-3xl">
          <span>
            In voice: <strong>{voice.room.name}</strong>
          </span>
          <div className="flex gap-2">
            <button className="btn btn-sm" onClick={() => selectRoom(voice.room)}>
              Go to room
            </button>
            <button className="btn btn-sm btn-outline btn-error" onClick={leave}>
              Leave
            </button>
          </div>
        </div>
      )}
      {content}
    </main>
  )

  return (
    // Side panel is always visible on large screens, an overlay on small ones.
    <div className="drawer min-h-screen bg-base-200 lg:drawer-open">
      <input
        id={DRAWER_ID}
        type="checkbox"
        className="drawer-toggle"
        checked={drawerOpen}
        onChange={(e) => setDrawerOpen(e.target.checked)}
      />

      <div className="drawer-content flex flex-col">
        <header className="navbar bg-base-100 shadow-sm lg:hidden">
          <label htmlFor={DRAWER_ID} className="btn btn-square btn-ghost" aria-label="Open rooms">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" className="size-6 stroke-current">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </label>
          <span className="px-2 text-lg font-bold">Orcavoice</span>
        </header>

        {voice ? (
          // Kept mounted while browsing other rooms so you stay connected.
          // Unmounting it (Leave) disconnects from LiveKit.
          <LiveKitRoom
            serverUrl={voice.url}
            token={voice.token}
            connect
            audio={false}
            video={false}
            onDisconnected={() => setVoice(null)}
            onError={(err) => {
              setVoiceError(`Voice connection failed: ${err.message}`)
              setVoice(null)
            }}
            className="flex flex-1 flex-col"
          >
            <RoomAudioRenderer />
            {main}
          </LiveKitRoom>
        ) : (
          main
        )}
      </div>

      <div className="drawer-side z-20">
        <label htmlFor={DRAWER_ID} aria-label="Close rooms" className="drawer-overlay" />
        <aside className="flex min-h-full w-72 flex-col gap-4 bg-base-100 p-4">
          <div>
            <h1 className="text-2xl font-bold">Orcavoice</h1>
            <p className="text-sm text-base-content/60">Available rooms</p>
          </div>
          <nav aria-label="Chatrooms" className="flex-1">
            <ChatroomList selectedId={selectedRoom?.id ?? null} onSelect={selectRoom} />
          </nav>
          {user && (
            <div className="flex items-center justify-between gap-2 border-t border-base-300 pt-3 text-sm">
              <span className="truncate">
                Signed in as <strong>{user.display_name || user.username}</strong>
              </span>
              <button className="btn btn-ghost btn-xs" onClick={signOut}>
                Sign out
              </button>
            </div>
          )}
        </aside>
      </div>
    </div>
  )
}

function EmptyState() {
  return (
    <div className="m-auto text-center text-base-content/60">
      <p className="text-lg">Pick a room to get started.</p>
    </div>
  )
}

interface RoomDetailsProps {
  room: Chatroom
  signedIn: boolean
  inOtherRoom: boolean
  joining: boolean
  error: string | null
  onJoin: () => void
}

function RoomDetails({ room, signedIn, inOtherRoom, joining, error, onJoin }: RoomDetailsProps) {
  return (
    <section className="card w-full max-w-3xl self-start bg-base-100 shadow-sm">
      <div className="card-body">
        <h2 className="card-title text-2xl">{room.name}</h2>
        {room.description && <p className="text-base-content/70">{room.description}</p>}
        <div className="flex flex-wrap gap-2 pt-2">
          <span className="badge badge-ghost">/{room.slug}</span>
          <span className="badge badge-ghost">Up to {room.max_participants} people</span>
        </div>

        <div className="mt-4 max-w-sm">
          {signedIn ? (
            <button className="btn btn-primary" onClick={onJoin} disabled={joining}>
              {joining ? (
                <span className="loading loading-spinner loading-sm" />
              ) : inOtherRoom ? (
                'Switch to this room'
              ) : (
                'Join room'
              )}
            </button>
          ) : (
            // After signing up, join right away.
            <SignUpForm onDone={onJoin} />
          )}
          {error && <p className="mt-2 text-sm text-error">{error}</p>}
        </div>
      </div>
    </section>
  )
}

export default App
