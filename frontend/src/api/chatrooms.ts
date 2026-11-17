import { useInfiniteQuery, useQueries } from '@tanstack/react-query'
import { apiFetch } from './client'

export interface Chatroom {
  id: string
  name: string
  slug: string
  description: string | null
  is_private: boolean
  max_participants: number
  owner_id: string | null
  inserted_at: string
  updated_at: string
}

export interface ChatroomPage {
  data: Chatroom[]
  next_cursor: string | null
}

export const chatroomKeys = {
  all: ['chatrooms'] as const,
  publicList: () => [...chatroomKeys.all, 'public'] as const,
}

const PAGE_SIZE = 20

export function fetchChatroomPage(cursor: string | null, signal?: AbortSignal) {
  const params = new URLSearchParams({ limit: String(PAGE_SIZE) })
  if (cursor) params.set('cursor', cursor)
  return apiFetch<ChatroomPage>(`/api/chatrooms?${params}`, { signal })
}

/** Public chatrooms, newest first, loaded a page at a time. */
export function usePublicChatrooms() {
  return useInfiniteQuery({
    queryKey: chatroomKeys.publicList(),
    queryFn: ({ pageParam, signal }) => fetchChatroomPage(pageParam, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => lastPage.next_cursor,
  })
}

export const occupancyKeys = {
  forRooms: (ids: string[]) => ['chatrooms', 'occupancy', ids] as const,
}

const OCCUPANCY_POLL_MS = 5_000

function fetchOccupancy(ids: string[], signal?: AbortSignal) {
  const params = new URLSearchParams({ ids: ids.join(',') })
  return apiFetch<{ data: Record<string, number> }>(`/api/chatrooms/occupancy?${params}`, {
    signal,
  }).then((res) => res.data)
}

/**
 * Live participant counts, keyed by room id, polled every few seconds.
 *
 * Takes rooms grouped as loaded (one group per list page) and makes one
 * request per group, so each request stays within the API's id limit no
 * matter how many pages have been loaded.
 */
export function useRoomOccupancy(idGroups: string[][]): Record<string, number> {
  return useQueries({
    queries: idGroups.map((ids) => ({
      queryKey: occupancyKeys.forRooms(ids),
      queryFn: ({ signal }: { signal: AbortSignal }) => fetchOccupancy(ids, signal),
      enabled: ids.length > 0,
      refetchInterval: OCCUPANCY_POLL_MS,
      staleTime: 0,
    })),
    combine: (results) => Object.assign({}, ...results.map((r) => r.data ?? {})),
  })
}
