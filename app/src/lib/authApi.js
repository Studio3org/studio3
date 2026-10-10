import { apiFetch, ApiError, setSession, updateSessionUser } from './api';

/// Sign-up, password-reset and onboarding calls — the web counterpart of the
/// app's AuthService + the onboarding half of UserService.

// ---- Sign-up ------------------------------------------------------------

export function generateOtp(email) {
  return apiFetch('/api/auth/otp/generate', { method: 'POST', body: { email: email.trim() } });
}

export function resendOtp(email) {
  return apiFetch('/api/auth/otp/resend', { method: 'POST', body: { email: email.trim() } });
}

/// Checks the code without consuming it — register sends the same code again.
export function verifyOtp(email, otp) {
  return apiFetch('/api/auth/otp/verify', { method: 'POST', body: { email: email.trim(), otp } });
}

/// → `{available, normalized, reason, message, suggestions[]}`
export async function checkUsername(username) {
  const data = await apiFetch(
    `/api/auth/username/check?username=${encodeURIComponent(username.trim())}`,
  );
  return {
    available: Boolean(data?.available),
    message: data?.message ?? null,
    suggestions: Array.isArray(data?.suggestions) ? data.suggestions : [],
  };
}

/// Creates the account and signs in with the returned token. The form only
/// gets here after the Terms of Use box was ticked on the first step.
export async function register({ username, name, email, password, otp, phone }) {
  const body = {
    username: username.trim(),
    name: name.trim(),
    email: email.trim(),
    password,
    otp,
    acceptedTerms: true,
  };
  if (phone?.trim()) body.phone = phone.trim();
  const data = await apiFetch('/api/auth/register', { method: 'POST', body });
  setSession(data.accessToken, data.user ?? null);
  return data.user;
}

// ---- Password reset -----------------------------------------------------

export function requestPasswordReset(email) {
  return apiFetch('/api/auth/forget-password', { method: 'POST', body: { email: email.trim() } });
}

export function resetPassword(token, newPassword) {
  return apiFetch('/api/auth/reset-password', { method: 'POST', body: { token, newPassword } });
}

// ---- Onboarding ---------------------------------------------------------

/// Every onboarding call returns the fresh UserMe; keep the stored copy in
/// sync so the App-level onboarding gate sees the latest state.
async function meCall(path, method, body) {
  const user = await apiFetch(path, { method, body, auth: true });
  if (user && typeof user === 'object') updateSessionUser(user);
  return user;
}

export const setRole = (role) => meCall('/api/user/me/role', 'PATCH', { role });

export const setOnboardingPreferences = ({ mediums, styles, themes }) =>
  meCall('/api/user/me/onboarding/preferences', 'POST', { mediums, styles, themes });

export const setOnboardingPhotos = (profilePhotoUrl) =>
  meCall(
    '/api/user/me/onboarding/photos',
    'POST',
    profilePhotoUrl ? { profilePhotoUrl } : { skip: true },
  );

export const completeOnboarding = () => meCall('/api/user/me/onboarding/complete', 'POST');

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;

/// Presign → PUT the raw bytes → public URL. The PUT goes straight to storage,
/// so it carries no auth header and no cookies.
export async function uploadProfilePhoto(file) {
  if (!IMAGE_TYPES.includes(file.type)) {
    throw new ApiError('Choose a JPEG, PNG or WebP image.', 400);
  }
  if (file.size > MAX_IMAGE_BYTES) {
    throw new ApiError('That image is over 20 MB.', 400);
  }
  const { presignedPutUrl, url } = await apiFetch('/api/media/presign', {
    method: 'POST',
    auth: true,
    body: { purpose: 'profile', contentType: file.type },
  });
  let res;
  try {
    res = await fetch(presignedPutUrl, {
      method: 'PUT',
      headers: { 'Content-Type': file.type },
      body: file,
      credentials: 'omit',
    });
  } catch {
    throw new ApiError("Couldn't upload the photo. Check your connection.", 0);
  }
  if (!res.ok) throw new ApiError(`Upload failed (${res.status})`, res.status);
  return url;
}
