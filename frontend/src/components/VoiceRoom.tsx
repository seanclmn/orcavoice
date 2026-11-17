import { useState } from 'react'
import {
  StartAudio,
  useConnectionState,
  useIsSpeaking,
  useLocalParticipant,
  useLocalParticipantPermissions,
  useParticipants,
} from '@livekit/components-react'
import { ConnectionState, type Participant } from 'livekit-client'
import type { Chatroom } from '../api/chatrooms'

interface VoiceRoomProps {
  room: Chatroom
  speakerLimit: number
  onLeave: () => void
}

/**
 * In-room view. Must render inside <LiveKitRoom>.
 *
 * Who may speak is decided by the server (first `speakerLimit` people to
 * join); this UI only reflects the permissions LiveKit reports.
 */
export function VoiceRoom({ room, speakerLimit, onLeave }: VoiceRoomProps) {
  const connection = useConnectionState()
  const participants = useParticipants()

  const speakers = sortByJoin(participants.filter(canSpeak))
  const listeners = sortByJoin(participants.filter((p) => !canSpeak(p)))

  return (
    <section className="card w-full max-w-3xl self-start bg-base-100 shadow-sm">
      <div className="card-body gap-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="card-title text-2xl">{room.name}</h2>
            <ConnectionBadge state={connection} />
          </div>
          <button className="btn btn-outline btn-error btn-sm" onClick={onLeave}>
            Leave
          </button>
        </div>

        {/* Browsers block audio until the user interacts; this appears only if needed. */}
        <StartAudio label="Click to enable audio" className="btn btn-warning btn-sm self-start" />

        <LocalControls speakerLimit={speakerLimit} />

        <ParticipantGroup
          title={`Speakers ${speakers.length}/${speakerLimit}`}
          participants={speakers}
        />
        <ParticipantGroup
          title={`Listeners ${listeners.length}`}
          participants={listeners}
          emptyText="No listeners."
        />
      </div>
    </section>
  )
}

function canSpeak(p: Participant) {
  return p.permissions?.canPublish === true
}

function sortByJoin(ps: Participant[]) {
  return [...ps].sort((a, b) => (a.joinedAt?.getTime() ?? 0) - (b.joinedAt?.getTime() ?? 0))
}

function ConnectionBadge({ state }: { state: ConnectionState }) {
  if (state === ConnectionState.Connected) {
    return <span className="badge badge-success badge-sm mt-1">Connected</span>
  }
  if (state === ConnectionState.Disconnected) {
    return <span className="badge badge-error badge-sm mt-1">Disconnected</span>
  }
  return (
    <span className="badge badge-ghost badge-sm mt-1 gap-1">
      <span className="loading loading-spinner loading-xs" /> {state}
    </span>
  )
}

function LocalControls({ speakerLimit }: { speakerLimit: number }) {
  const { localParticipant, isMicrophoneEnabled } = useLocalParticipant()
  const permissions = useLocalParticipantPermissions()
  const [micError, setMicError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  // Permissions arrive just after connecting; treat unknown as "not yet".
  if (!permissions) return null

  if (!permissions.canPublish) {
    return (
      <div role="status" className="alert alert-info alert-soft">
        <span>
          You're listening. Up to {speakerLimit} {speakerLimit === 1 ? 'person' : 'people'} can
          talk at once, in the order they joined. You'll be able to speak automatically when a
          spot opens up.
        </span>
      </div>
    )
  }

  const toggleMic = async () => {
    setBusy(true)
    setMicError(null)
    try {
      await localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled)
    } catch (err) {
      setMicError(err instanceof Error ? err.message : 'Could not access microphone')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center gap-3">
        <button
          className={`btn ${isMicrophoneEnabled ? 'btn-primary' : 'btn-outline'}`}
          onClick={toggleMic}
          disabled={busy}
          aria-pressed={isMicrophoneEnabled}
        >
          {isMicrophoneEnabled ? 'Mute mic' : 'Unmute mic'}
        </button>
        <span className="text-sm text-base-content/70">You're a speaker.</span>
      </div>
      {micError && <p className="text-sm text-error">{micError}</p>}
    </div>
  )
}

function ParticipantGroup({
  title,
  participants,
  emptyText = 'Nobody yet.',
}: {
  title: string
  participants: Participant[]
  emptyText?: string
}) {
  return (
    <div>
      <h3 className="mb-2 text-sm font-semibold uppercase tracking-wide text-base-content/60">
        {title}
      </h3>
      {participants.length === 0 ? (
        <p className="text-sm text-base-content/50">{emptyText}</p>
      ) : (
        <ul className="flex flex-col gap-1">
          {participants.map((p) => (
            <ParticipantRow key={p.identity} participant={p} />
          ))}
        </ul>
      )}
    </div>
  )
}

function ParticipantRow({ participant }: { participant: Participant }) {
  const isSpeaking = useIsSpeaking(participant)
  const speaker = canSpeak(participant)
  const name = participant.name || participant.identity

  return (
    <li className="flex items-center gap-3 rounded-box px-2 py-1.5 hover:bg-base-200">
      <div className="avatar avatar-placeholder">
        <div
          className={`w-8 rounded-full bg-neutral text-neutral-content ring-2 ring-offset-2 ring-offset-base-100 ${
            isSpeaking ? 'ring-success' : 'ring-transparent'
          }`}
        >
          <span className="text-xs">{name.slice(0, 2).toUpperCase()}</span>
        </div>
      </div>
      <span className="truncate">
        {name}
        {participant.isLocal && <span className="text-base-content/50"> (you)</span>}
      </span>
      <span className="ml-auto text-xs text-base-content/60">
        {!speaker ? 'Muted (listener)' : participant.isMicrophoneEnabled ? 'Mic on' : 'Mic off'}
      </span>
    </li>
  )
}
