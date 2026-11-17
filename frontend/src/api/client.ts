import { getCurrentUser } from './session'

/** Error thrown for non-2xx API responses, carrying the backend's error payload. */
export class ApiError extends Error {
  readonly status: number
  readonly errors: Record<string, unknown> | undefined

  constructor(status: number, errors?: Record<string, unknown>) {
    const detail = typeof errors?.detail === 'string' ? errors.detail : `Request failed (${status})`
    super(detail)
    this.status = status
    this.errors = errors
  }
}

/**
 * Fetches JSON from the Phoenix API. Paths are relative ("/api/..."), which
 * Vite proxies to the backend in development.
 */
export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const user = getCurrentUser()
  const res = await fetch(path, {
    ...init,
    headers: {
      Accept: 'application/json',
      ...(user ? { 'x-user-id': user.id } : {}),
      ...init?.headers,
    },
  })

  if (!res.ok) {
    const body = await res.json().catch(() => undefined)
    throw new ApiError(res.status, body?.errors)
  }

  return res.status === 204 ? (undefined as T) : res.json()
}
