/// Same rules as the app's AuthValidators.password (lib/utils/auth_validators.dart),
/// so an account created on the web can't have a password the app would reject.
export function passwordProblem(value) {
  const v = value ?? '';
  if (!v) return 'Password is required';
  if (v.length < 8) return 'At least 8 characters';
  if (!/[A-Z]/.test(v)) return 'Include an uppercase letter';
  if (!/[0-9]/.test(v)) return 'Include a number';
  return null;
}
