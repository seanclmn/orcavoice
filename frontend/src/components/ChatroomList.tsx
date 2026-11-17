import { useMemo } from 'react'
import { usePublicChatrooms, useRoomOccupancy, type Chatroom } from '../api/chatrooms'

interface ChatroomListProps {
  selectedId: string | null
  onSelect: (room: Chatroom) => void
}

/** Compact, selectable list of public chatrooms for the side panel. */
export function ChatroomList({ selectedId, onSelect }: ChatroomListProps) {
  const { data, error, isPending, isError, refetch, fetchNextPage, hasNextPage, isFetchingNextPage } =
    usePublicChatrooms()

  const idGroups = useMemo(
    () => data?.pages.map((page) => page.data.map((room) => room.id)) ?? [],
    [data],
  )
  const occupancy = useRoomOccupancy(idGroups)

  if (isPending) {
    return (
      <div className="flex justify-center py-8">
        <span className="loading loading-spinner" aria-label="Loading chatrooms" />
      </div>
    )
  }

  if (isError) {
    return (
      <div role="alert" className="alert alert-error alert-soft flex-col items-start gap-2 text-sm">
        <span>Couldn't load chatrooms: {error.message}</span>
        <button className="btn btn-xs" onClick={() => refetch()}>
          Retry
        </button>
      </div>
    )
  }

  const rooms = data.pages.flatMap((page) => page.data)

  if (rooms.length === 0) {
    return <p className="px-4 py-8 text-center text-sm text-base-content/60">No chatrooms yet.</p>
  }

  return (
    <>
      <ul className="menu w-full gap-1 p-0">
        {rooms.map((room) => (
          <li key={room.id}>
            <button
              className={room.id === selectedId ? 'menu-active' : undefined}
              aria-current={room.id === selectedId ? 'true' : undefined}
              onClick={() => onSelect(room)}
            >
              <span className="truncate">{room.name}</span>
              <ParticipantCount count={occupancy[room.id]} max={room.max_participants} />
            </button>
          </li>
        ))}
      </ul>

      {hasNextPage && (
        <button
          className="btn btn-ghost btn-sm mt-2 w-full"
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
        >
          {isFetchingNextPage ? <span className="loading loading-spinner loading-xs" /> : 'Load more'}
        </button>
      )}
    </>
  )
}

/** "👤 3" style count; undefined means counts haven't loaded yet. */
function ParticipantCount({ count, max }: { count: number | undefined; max: number }) {
  const label =
    count === undefined ? 'Participant count loading' : `${count} of ${max} people in room`

  return (
    <span
      className={`ml-auto flex shrink-0 items-center gap-1 text-xs tabular-nums ${
        count ? 'text-success' : 'text-base-content/50'
      }`}
      aria-label={label}
      title={label}
    >
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="size-3.5" aria-hidden="true">
        <path d="M10 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM3.465 14.493a1.23 1.23 0 0 0 .41 1.412A9.957 9.957 0 0 0 10 18c2.31 0 4.438-.784 6.131-2.1.43-.333.604-.903.408-1.41a7.002 7.002 0 0 0-13.074.003Z" />
      </svg>
      {count ?? '–'}
    </span>
  )
}
