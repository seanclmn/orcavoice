import { useSyncExternalStore } from 'react'
import type { CurrentUser } from './users'

/**
 * PLACEHOLDER session until real auth exists: the signed-in user is kept in
 * sessionStorage (per tab, so you can test as different users in different
 * tabs) and sent to the backend as an `x-user-id` header.
 */
const KEY = 'orcavoice.currentUser'
const listeners = new Set<() => void>()

let cached: CurrentUser | null = read()

function read(): CurrentUser | null {
  try {
    const raw = sessionStorage.getItem(KEY)
    return raw ? (JSON.parse(raw) as CurrentUser) : null
  } catch {
    return null
  }
}

export function getCurrentUser(): CurrentUser | null {
  return cached
}

export function setCurrentUser(user: CurrentUser | null) {
  cached = user
  try {
    if (user) sessionStorage.setItem(KEY, JSON.stringify(user))
    else sessionStorage.removeItem(KEY)
  } catch {
    // Storage unavailable (e.g. private mode): keep the in-memory session.
  }
  listeners.forEach((notify) => notify())
}

export function useCurrentUser(): CurrentUser | null {
  return useSyncExternalStore(
    (notify) => {
      listeners.add(notify)
      return () => listeners.delete(notify)
    },
    getCurrentUser,
  )
}
