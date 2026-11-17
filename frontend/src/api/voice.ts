import { useMutation } from '@tanstack/react-query'
import { apiFetch } from './client'

export interface VoiceSession {
  roomId: string
  token: string
  url: string
  speakerLimit: number
}

interface TokenResponse {
  data: { token: string; url: string; room_name: string; speaker_limit: number }
}

/** Requests credentials to join a room's voice channel as the current user. */
export function useJoinVoice() {
  return useMutation({
    mutationFn: (roomId: string): Promise<VoiceSession> =>
      apiFetch<TokenResponse>(`/api/chatrooms/${roomId}/token`, { method: 'POST' }).then(
        ({ data }) => ({
          roomId,
          token: data.token,
          url: data.url,
          speakerLimit: data.speaker_limit,
        }),
      ),
  })
}
