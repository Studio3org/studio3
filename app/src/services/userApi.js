import { apiFetch } from './apiClient';

/** PATCH /api/user/me — see docs/api/flows/user-profile.md. All fields optional;
 * unset ones in `body` are left unchanged server-side. Returns the full profile. */
export function updateMe(body) {
  return apiFetch('/api/user/me', { method: 'PATCH', auth: true, body });
}

/** PATCH /api/user/me/username — separate endpoint, 30-day cooldown between
 * changes enforced server-side (surfaced via the thrown ApiError's message). */
export function changeUsername(username) {
  return apiFetch('/api/user/me/username', { method: 'PATCH', auth: true, body: { username } });
}

/** GET /api/auth/username/check — live availability check while editing the
 * current user's own username (`for_user_id=me` excludes their own existing
 * username from the "taken" result). Mirrors UserService.checkUsername in
 * the Flutter app's edit-profile screen. */
export function checkUsername(username) {
  return apiFetch(`/api/auth/username/check?username=${encodeURIComponent(username)}&for_user_id=me`, {
    auth: true,
  });
}
