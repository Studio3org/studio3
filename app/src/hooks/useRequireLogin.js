import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

/// Guests can browse public content (App Store guideline 5.1.1(v)); account actions —
/// like, save, comment, follow, message, post, report, block — call this first. A guest is
/// sent to /login, which returns them here afterwards (LoginPage honours `state.from`).
export function useRequireLogin() {
  const { status } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  return () => {
    if (status === 'authenticated') return true;
    navigate('/login', { state: { from: location } });
    return false;
  };
}
