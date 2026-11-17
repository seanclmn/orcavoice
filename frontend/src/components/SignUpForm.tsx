import { useState, type FormEvent } from 'react'
import { useSignUp } from '../api/users'
import { ApiError } from '../api/client'

/** Minimal "pick a username" form shown before a first-time user can join. */
export function SignUpForm({ onDone }: { onDone?: () => void }) {
  const [username, setUsername] = useState('')
  const [displayName, setDisplayName] = useState('')
  const signUp = useSignUp()

  const fieldErrors = signUp.error instanceof ApiError ? signUp.error.errors : undefined
  const usernameError = (fieldErrors?.username as string[] | undefined)?.join(', ')

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    // mutateAsync rather than mutate's onSuccess: signing in unmounts this
    // form, and per-call callbacks don't fire after unmount.
    try {
      await signUp.mutateAsync({
        username: username.trim(),
        display_name: displayName.trim() || undefined,
      })
    } catch {
      return // error is shown from signUp.error
    }
    onDone?.()
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-3">
      <p className="text-sm text-base-content/70">Pick a name so others know who's talking.</p>

      <label className="form-control">
        <span className="label-text mb-1">Username</span>
        <input
          className={`input input-bordered w-full ${usernameError ? 'input-error' : ''}`}
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="orca_fan"
          autoComplete="username"
          required
          minLength={3}
          maxLength={32}
          pattern="[a-zA-Z0-9_]+"
          title="Letters, numbers and underscores"
        />
        {usernameError && <span className="mt-1 text-sm text-error">Username {usernameError}</span>}
      </label>

      <label className="form-control">
        <span className="label-text mb-1">Display name (optional)</span>
        <input
          className="input input-bordered w-full"
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
          placeholder="Orca Fan"
          maxLength={64}
        />
      </label>

      {signUp.isError && !usernameError && (
        <p className="text-sm text-error">{signUp.error.message}</p>
      )}

      <button className="btn btn-primary" disabled={signUp.isPending}>
        {signUp.isPending ? <span className="loading loading-spinner loading-sm" /> : 'Continue'}
      </button>
    </form>
  )
}
