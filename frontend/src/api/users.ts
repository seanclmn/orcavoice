import { useMutation } from '@tanstack/react-query'
import { apiFetch } from './client'
import { setCurrentUser } from './session'

export interface CurrentUser {
  id: string
  username: string
  email: string
  display_name: string | null
  avatar_url: string | null
}

interface SignUpInput {
  username: string
  display_name?: string
}

/** Creates a user and makes them this tab's current user. */
export function useSignUp() {
  return useMutation({
    mutationFn: (input: SignUpInput) =>
      apiFetch<{ data: CurrentUser }>('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // No email collection yet; generate a placeholder that satisfies the API.
        body: JSON.stringify({ ...input, email: `${input.username}@users.orcavoice.local` }),
      }).then((res) => res.data),
    onSuccess: (user) => setCurrentUser(user),
  })
}
