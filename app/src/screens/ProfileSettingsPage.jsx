import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiFetch, ApiError } from '../services/apiClient';
import {
  Store,
  Wallet,
  BarChart3,
  ShoppingBag,
  ShieldCheck,
  Receipt,
  User,
  Layers,
  MapPin,
  Eye,
  Shield,
  UserPlus,
  Ban,
  Flag,
  Lock,
  Mail,
  Smartphone,
  Bell,
  Sliders,
  LogOut,
  Trash2,
  ChevronRight,
} from 'lucide-react';
import './ProfileSettingsPage.css';

// Same fixed set the backend validates against (auth_controller.DELETION_REASONS) — kept
// as labelled pairs here since the API only ever sees the value, never this copy.
const DELETION_REASONS = [
  { value: 'not_using', label: "I'm not using it enough" },
  { value: 'found_alternative', label: 'I found another platform' },
  { value: 'fees_too_high', label: 'The fees are too high' },
  { value: 'privacy_concerns', label: 'Privacy concerns' },
  { value: 'too_many_notifications', label: 'Too many notifications' },
  { value: 'technical_issues', label: 'Technical issues or bugs' },
  { value: 'poor_support', label: 'Poor customer support' },
  { value: 'other', label: 'Other' },
];

export function ProfileSettingsPage() {
  const navigate = useNavigate();
  const { user, logout, refreshUser } = useAuth();

  const [sellerEnabled, setSellerEnabled] = useState(Boolean(user?.isSeller || user?.sellerEnabled));
  const [loadingSeller, setLoadingSeller] = useState(false);
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [deleteReason, setDeleteReason] = useState('');
  const [deleteFeedback, setDeleteFeedback] = useState('');
  const [deletePassword, setDeletePassword] = useState('');
  const [deleteError, setDeleteError] = useState(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (user) {
      setSellerEnabled(Boolean(user.isSeller || user.sellerEnabled));
    }
  }, [user]);

  const handleSellerToggle = async (e) => {
    const newValue = e.target.checked;
    setSellerEnabled(newValue);
    setLoadingSeller(true);
    try {
      await apiFetch('/api/user/me', {
        method: 'PATCH',
        auth: true,
        body: { isSeller: newValue, sellerEnabled: newValue },
      });
      await refreshUser();
    } catch {
      // Revert if API call fails
      setSellerEnabled(!newValue);
    } finally {
      setLoadingSeller(false);
    }
  };

  const handleLogoutConfirmed = async () => {
    setLogoutModalOpen(false);
    await logout();
    navigate('/login', { replace: true });
  };

  const closeDeleteModal = () => {
    if (deleting) return;
    setDeleteModalOpen(false);
    setDeleteReason('');
    setDeleteFeedback('');
    setDeletePassword('');
    setDeleteError(null);
  };

  // Mirrors the Flutter app's own delete flow (profile_settings_page.dart /
  // AuthService.deleteAccount) — same endpoint, same password requirement, same
  // server-side refusal (400) while active listings or in-progress orders exist. The
  // reason is required server-side (auth_controller.DELETION_REASONS); feedback is not.
  const handleDeleteAccount = async () => {
    if (!deleteReason || !deletePassword || deleting) return;
    setDeleting(true);
    setDeleteError(null);
    try {
      await apiFetch('/api/users/me', {
        method: 'DELETE',
        auth: true,
        body: {
          password: deletePassword,
          reason: deleteReason,
          feedback: deleteFeedback.trim() || undefined,
        },
      });
      await logout();
      navigate('/login', { replace: true });
    } catch (e) {
      setDeleting(false);
      setDeleteError(e instanceof ApiError ? e.message : 'Could not delete your account. Please try again.');
    }
  };

  return (
    <div className="settings-page">
      <div className="settings-inner">
        <div className="settings-header">
          <h1 className="settings-title">Profile Settings</h1>
        </div>

        {/* Ops console. Shown only to staff — `isAdmin` is sent only to the
            account itself, so this section does not exist for anyone else. It
            decides what is drawn, never what is permitted: every admin route
            re-checks the flag server-side on each request. */}
        {user?.isAdmin && (
          <div className="settings-section">
            <h2 className="settings-section-title">Staff</h2>
            <div className="settings-card" onClick={() => navigate('/admin')}>
              <div className="settings-card-left">
                <span className="settings-card-icon">
                  <ShieldCheck size={20} />
                </span>
                <span className="settings-card-label">Admin console</span>
              </div>
              <ChevronRight size={18} color="#8c8880" />
            </div>
          </div>
        )}

        {/* Seller Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Seller</h2>
          <div className="settings-card" onClick={() => {}}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Store size={20} />
              </span>
              <span className="settings-card-label">Seller account</span>
            </div>
            <label className="settings-switch" onClick={(e) => e.stopPropagation()}>
              <input
                type="checkbox"
                checked={sellerEnabled}
                disabled={loadingSeller}
                onChange={handleSellerToggle}
              />
              <span className="settings-slider" />
            </label>
          </div>

          {sellerEnabled && (
            <>
              <div className="settings-card" onClick={() => alert('Payout setup form')}>
                <div className="settings-card-left">
                  <span className="settings-card-icon">
                    <Wallet size={20} />
                  </span>
                  <span className="settings-card-label">Payout setup</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span className="settings-card-badge">Required</span>
                  <ChevronRight size={18} color="#8c8880" />
                </div>
              </div>

              <div className="settings-card" onClick={() => alert('Seller analytics: 0 sales, 12 saves')}>
                <div className="settings-card-left">
                  <span className="settings-card-icon">
                    <BarChart3 size={20} />
                  </span>
                  <span className="settings-card-label">Seller analytics</span>
                </div>
                <ChevronRight size={18} color="#8c8880" />
              </div>

              <div className="settings-card" onClick={() => alert('No sales yet')}>
                <div className="settings-card-left">
                  <span className="settings-card-icon">
                    <ShoppingBag size={20} />
                  </span>
                  <span className="settings-card-label">My sales</span>
                </div>
                <ChevronRight size={18} color="#8c8880" />
              </div>
            </>
          )}

          <div className="settings-card" onClick={() => alert('No order history')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Receipt size={20} />
              </span>
              <span className="settings-card-label">My orders</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>
        </div>

        {/* Account Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Account</h2>
          <div className="settings-card" onClick={() => navigate('/profile/edit')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <User size={20} />
              </span>
              <span className="settings-card-label">Edit profile</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => alert('Series manager')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Layers size={20} />
              </span>
              <span className="settings-card-label">Manage series</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => alert('Shipping addresses manager')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <MapPin size={20} />
              </span>
              <span className="settings-card-label">Shipping addresses</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => navigate(`/profile?username=${user?.username}`)}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Eye size={20} />
              </span>
              <span className="settings-card-label">See profile as viewer</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>
        </div>

        {/* Privacy Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Privacy</h2>
          <div className="settings-card" onClick={() => alert('Profile visibility & messaging settings')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Shield size={20} />
              </span>
              <span className="settings-card-label">Profile visibility & messaging</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => navigate('/inbox')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <UserPlus size={20} />
              </span>
              <span className="settings-card-label">Follow requests</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => alert('No blocked accounts')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Ban size={20} />
              </span>
              <span className="settings-card-label">Blocked accounts</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => alert('No active reports')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Flag size={20} />
              </span>
              <span className="settings-card-label">My reports</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>
        </div>

        {/* Login & Security Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Login & security</h2>
          <div className="settings-card" onClick={() => alert('Password change form')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Lock size={20} />
              </span>
              <span className="settings-card-label">Password & security</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => alert('Change email form')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Mail size={20} />
              </span>
              <span className="settings-card-label">Change email</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => setLogoutModalOpen(true)}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Smartphone size={20} />
              </span>
              <span className="settings-card-label">Log out of all devices</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>
        </div>

        {/* Notifications Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Notifications</h2>
          <div className="settings-card" onClick={() => navigate('/inbox')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Bell size={20} />
              </span>
              <span className="settings-card-label">Notifications</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>

          <div className="settings-card" onClick={() => alert('Notification preferences')}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Sliders size={20} />
              </span>
              <span className="settings-card-label">Notification preferences</span>
            </div>
            <ChevronRight size={18} color="#8c8880" />
          </div>
        </div>

        {/* Log Out */}
        <div className="settings-section" style={{ marginTop: 24 }}>
          <div className="settings-card is-destructive" onClick={() => setLogoutModalOpen(true)}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <LogOut size={20} />
              </span>
              <span className="settings-card-label">Log out</span>
            </div>
          </div>

          <div className="settings-card is-destructive" onClick={() => setDeleteModalOpen(true)}>
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Trash2 size={20} />
              </span>
              <span className="settings-card-label">Delete account</span>
            </div>
          </div>
        </div>
      </div>

      {/* Log Out Modal */}
      {logoutModalOpen && (
        <div className="settings-modal-overlay" onClick={() => setLogoutModalOpen(false)}>
          <div className="settings-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="settings-modal-title">Log out?</h3>
            <p className="settings-modal-body">
              You'll need to log back in to use Studio 3.
            </p>
            <div className="settings-modal-actions">
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-cancel"
                onClick={() => setLogoutModalOpen(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-confirm"
                onClick={handleLogoutConfirmed}
              >
                Log out
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Account Modal */}
      {deleteModalOpen && (
        <div className="settings-modal-overlay" onClick={closeDeleteModal}>
          <div className="settings-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="settings-modal-title">Delete your account?</h3>
            <p className="settings-modal-body">
              This permanently removes your profile, posts, and listings. This cannot
              be undone.
            </p>

            <label className="settings-modal-label">Why are you leaving?</label>
            <select
              className="settings-modal-input"
              value={deleteReason}
              disabled={deleting}
              onChange={(e) => setDeleteReason(e.target.value)}
            >
              <option value="" disabled>Choose a reason</option>
              {DELETION_REASONS.map((r) => (
                <option key={r.value} value={r.value}>{r.label}</option>
              ))}
            </select>

            <textarea
              className="settings-modal-input settings-modal-textarea"
              placeholder="Anything else you'd like us to know? (optional)"
              value={deleteFeedback}
              disabled={deleting}
              onChange={(e) => setDeleteFeedback(e.target.value)}
              rows={3}
            />

            <label className="settings-modal-label">Confirm your password</label>
            <input
              type="password"
              className="settings-modal-input"
              placeholder="Password"
              value={deletePassword}
              disabled={deleting}
              onChange={(e) => setDeletePassword(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleDeleteAccount()}
            />
            {deleteError && <p className="settings-modal-error">{deleteError}</p>}
            <div className="settings-modal-actions">
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-cancel"
                onClick={closeDeleteModal}
                disabled={deleting}
              >
                Cancel
              </button>
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-confirm"
                onClick={handleDeleteAccount}
                disabled={!deleteReason || !deletePassword || deleting}
              >
                {deleting ? 'Deleting…' : 'Delete account'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
