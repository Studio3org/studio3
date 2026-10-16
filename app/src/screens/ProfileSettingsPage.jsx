import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiFetch, ApiError, API_BASE_URL } from '../services/apiClient';
import { friendlyError } from '../services/socialApi';
import { disableSeller, enableSeller, getSellerAnalytics, logoutAllDevices } from '../services/profileApi';
import { profileHref } from '../utils/contentLinks';
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
  FileText,
  ExternalLink,
} from 'lucide-react';
import './ProfileSettingsPage.css';
import './settings/settings.css';

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

/// One tappable settings row.
function SettingsRow({ icon: Icon, label, onClick, trailing, destructive = false }) {
  return (
    <div className={`settings-card${destructive ? ' is-destructive' : ''}`} onClick={onClick}>
      <div className="settings-card-left">
        <span className="settings-card-icon">
          <Icon size={20} />
        </span>
        <span className="settings-card-label">{label}</span>
      </div>
      {trailing !== undefined ? trailing : !destructive && <ChevronRight size={18} color="#8c8880" />}
    </div>
  );
}

/// Payouts (Stripe Connect onboarding), orders, sales, series and addresses still live only in
/// the iOS/Android app — shown honestly rather than as dead links.
function AppOnlyRow({ icon: Icon, label }) {
  return (
    <div className="settings-card is-static" aria-disabled="true">
      <div className="settings-card-left">
        <span className="settings-card-icon">
          <Icon size={20} />
        </span>
        <span className="settings-card-label">{label}</span>
      </div>
      <span className="settings-card-badge settings-card-badge--muted">In the Studio3 app</span>
    </div>
  );
}

export function ProfileSettingsPage() {
  const navigate = useNavigate();
  const { user, logout, refreshUser } = useAuth();

  const [sellerEnabled, setSellerEnabled] = useState(Boolean(user?.sellerEnabled || user?.isSeller));
  const [loadingSeller, setLoadingSeller] = useState(false);
  const [sellerError, setSellerError] = useState(null);
  const [sellerLocationOpen, setSellerLocationOpen] = useState(false);
  const [sellerLocation, setSellerLocation] = useState('');
  const [analyticsOpen, setAnalyticsOpen] = useState(false);
  const [analytics, setAnalytics] = useState(null);
  const [analyticsError, setAnalyticsError] = useState(null);
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);
  const [logoutAllOpen, setLogoutAllOpen] = useState(false);
  const [logoutAllBusy, setLogoutAllBusy] = useState(false);
  const [logoutAllError, setLogoutAllError] = useState(null);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [deleteReason, setDeleteReason] = useState('');
  const [deleteFeedback, setDeleteFeedback] = useState('');
  const [deletePassword, setDeletePassword] = useState('');
  const [deleteError, setDeleteError] = useState(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (user) {
      setSellerEnabled(Boolean(user.sellerEnabled || user.isSeller));
    }
  }, [user]);

  // Seller mode has dedicated endpoints (PATCH /api/user/me ignores it): enabling needs a
  // seller location; disabling is refused while listings or sales are in flight.
  const applySeller = async (enable, location) => {
    setLoadingSeller(true);
    setSellerError(null);
    setSellerEnabled(enable);
    try {
      if (enable) {
        await enableSeller(location ? { location } : { useProfileLocation: true });
      } else {
        await disableSeller();
      }
      setSellerLocationOpen(false);
      await refreshUser().catch(() => {});
    } catch (e) {
      setSellerEnabled(!enable);
      setSellerError(friendlyError(e));
    } finally {
      setLoadingSeller(false);
    }
  };

  const handleSellerToggle = (e) => {
    const newValue = e.target.checked;
    if (newValue && !user?.location) {
      setSellerLocation('');
      setSellerError(null);
      setSellerLocationOpen(true);
      return;
    }
    applySeller(newValue);
  };

  const openAnalytics = async () => {
    setAnalyticsOpen(true);
    setAnalyticsError(null);
    setAnalytics(null);
    try {
      setAnalytics(await getSellerAnalytics());
    } catch (e) {
      setAnalyticsError(friendlyError(e));
    }
  };

  const handleLogoutConfirmed = async () => {
    setLogoutModalOpen(false);
    await logout();
    navigate('/login', { replace: true });
  };

  const handleLogoutAll = async () => {
    if (logoutAllBusy) return;
    setLogoutAllBusy(true);
    setLogoutAllError(null);
    try {
      await logoutAllDevices();
      await logout();
      navigate('/login', { replace: true });
    } catch (e) {
      setLogoutAllBusy(false);
      setLogoutAllError(friendlyError(e));
    }
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
  // server-side refusal (400) while active listings or in-progress orders exist.
  // reason/feedback are no longer validated server-side but are still passed along
  // as optional context.
  const handleDeleteAccount = async () => {
    if (!deletePassword || deleting) return;
    setDeleting(true);
    setDeleteError(null);
    try {
      await apiFetch('/api/user/me', {
        method: 'DELETE',
        auth: true,
        body: {
          password: deletePassword,
          reason: deleteReason || undefined,
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
            <SettingsRow icon={ShieldCheck} label="Admin console" onClick={() => navigate('/admin')} />
          </div>
        )}

        {/* Seller Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Seller</h2>
          <div className="settings-card is-static">
            <div className="settings-card-left">
              <span className="settings-card-icon">
                <Store size={20} />
              </span>
              <span className="settings-card-label">Seller account</span>
            </div>
            <label className="settings-switch" onClick={(e) => e.stopPropagation()}>
              <input
                type="checkbox"
                aria-label="Seller account"
                checked={sellerEnabled}
                disabled={loadingSeller}
                onChange={handleSellerToggle}
              />
              <span className="settings-slider" />
            </label>
          </div>
          {sellerError && !sellerLocationOpen && <p className="settings-error" style={{ margin: '-2px 4px 10px' }}>{sellerError}</p>}

          {sellerEnabled && (
            <>
              <AppOnlyRow icon={Wallet} label="Payout setup" />
              <SettingsRow icon={BarChart3} label="Seller analytics" onClick={openAnalytics} />
              <AppOnlyRow icon={ShoppingBag} label="My sales" />
            </>
          )}

          <AppOnlyRow icon={Receipt} label="My orders" />
          <p className="settings-note">
            Payouts, orders and sales are managed in the Studio3 app for iOS and Android.
          </p>
        </div>

        {/* Account Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Account</h2>
          <SettingsRow icon={User} label="Edit profile" onClick={() => navigate('/profile/edit')} />
          <AppOnlyRow icon={Layers} label="Manage series" />
          <AppOnlyRow icon={MapPin} label="Shipping addresses" />
          <SettingsRow
            icon={Eye}
            label="See profile as viewer"
            onClick={() => user?.username && navigate(`${profileHref(user.username)}?view=public`)}
          />
        </div>

        {/* Privacy Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Privacy</h2>
          <SettingsRow icon={Shield} label="Profile visibility & messaging" onClick={() => navigate('/settings/privacy')} />
          <SettingsRow icon={UserPlus} label="Follow requests" onClick={() => navigate('/inbox?tab=requests')} />
          <SettingsRow icon={Ban} label="Blocked accounts" onClick={() => navigate('/settings/blocked')} />
          <SettingsRow icon={Flag} label="My reports" onClick={() => navigate('/settings/reports')} />
        </div>

        {/* Login & Security Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Login & security</h2>
          <SettingsRow icon={Lock} label="Password & security" onClick={() => navigate('/settings/password')} />
          <SettingsRow icon={Mail} label="Change email" onClick={() => navigate('/settings/email')} />
          <SettingsRow
            icon={Smartphone}
            label="Log out of all devices"
            onClick={() => {
              setLogoutAllError(null);
              setLogoutAllOpen(true);
            }}
          />
        </div>

        {/* Notifications Section */}
        <div className="settings-section">
          <h2 className="settings-section-title">Notifications</h2>
          <SettingsRow icon={Bell} label="Notifications" onClick={() => navigate('/inbox?tab=notifications')} />
          <SettingsRow icon={Sliders} label="Notification preferences" onClick={() => navigate('/settings/notifications')} />
        </div>

        {/* About */}
        <div className="settings-section">
          <h2 className="settings-section-title">About</h2>
          <SettingsRow
            icon={FileText}
            label="Terms of Use"
            onClick={() => window.open(`${API_BASE_URL}/terms`, '_blank', 'noopener,noreferrer')}
            trailing={<ExternalLink size={16} color="#8c8880" />}
          />
        </div>

        {/* Log Out */}
        <div className="settings-section" style={{ marginTop: 24 }}>
          <SettingsRow icon={LogOut} label="Log out" destructive onClick={() => setLogoutModalOpen(true)} />
          <SettingsRow icon={Trash2} label="Delete account" destructive onClick={() => setDeleteModalOpen(true)} />
        </div>
      </div>

      {/* Seller location (required to enable seller mode when the profile has none) */}
      {sellerLocationOpen && (
        <div className="settings-modal-overlay" onClick={() => !loadingSeller && setSellerLocationOpen(false)}>
          <div className="settings-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="settings-modal-title">Where do you ship from?</h3>
            <p className="settings-modal-body">
              Collectors see this on your listings. You can change it later in Edit profile.
            </p>
            <label className="settings-modal-label" htmlFor="seller-location">Location</label>
            <input
              id="seller-location"
              className="settings-modal-input"
              placeholder="City, Country"
              value={sellerLocation}
              disabled={loadingSeller}
              onChange={(e) => setSellerLocation(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && sellerLocation.trim() && applySeller(true, sellerLocation.trim())}
            />
            {sellerError && <p className="settings-modal-error">{sellerError}</p>}
            <div className="settings-modal-actions">
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-cancel"
                disabled={loadingSeller}
                onClick={() => setSellerLocationOpen(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="settings-modal-btn settings-primary-btn"
                disabled={!sellerLocation.trim() || loadingSeller}
                onClick={() => applySeller(true, sellerLocation.trim())}
              >
                {loadingSeller ? 'Turning on…' : 'Turn on seller mode'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Seller analytics */}
      {analyticsOpen && (
        <div className="settings-modal-overlay" onClick={() => setAnalyticsOpen(false)}>
          <div className="settings-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="settings-modal-title">Seller analytics</h3>
            <p className="settings-modal-body">All-time activity on your pieces.</p>
            {!analytics && !analyticsError && (
              <div className="settings-loading" style={{ minHeight: 100 }}>
                <span className="settings-spinner" />
              </div>
            )}
            {analyticsError && <p className="settings-modal-error">{analyticsError}</p>}
            {analytics && (
              <div className="settings-stats">
                {[
                  ['savesCount', 'Saves'],
                  ['likesCount', 'Likes'],
                  ['inquiriesCount', 'Inquiries'],
                  ['salesCount', 'Sales'],
                ].map(([key, label]) => (
                  <div key={key} className="settings-stat">
                    <span className="settings-stat-val">{Number(analytics[key] ?? 0).toLocaleString()}</span>
                    <span className="settings-stat-lbl">{label}</span>
                  </div>
                ))}
              </div>
            )}
            <div className="settings-modal-actions">
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-cancel"
                onClick={() => setAnalyticsOpen(false)}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Log out of all devices */}
      {logoutAllOpen && (
        <div className="settings-modal-overlay" onClick={() => !logoutAllBusy && setLogoutAllOpen(false)}>
          <div className="settings-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="settings-modal-title">Log out of all devices?</h3>
            <p className="settings-modal-body">
              This signs you out everywhere — the app on your phone, other browsers and this one.
            </p>
            {logoutAllError && <p className="settings-modal-error">{logoutAllError}</p>}
            <div className="settings-modal-actions">
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-cancel"
                disabled={logoutAllBusy}
                onClick={() => setLogoutAllOpen(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="settings-modal-btn settings-modal-btn-confirm"
                disabled={logoutAllBusy}
                onClick={handleLogoutAll}
              >
                {logoutAllBusy ? 'Logging out…' : 'Log out everywhere'}
              </button>
            </div>
          </div>
        </div>
      )}

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
                disabled={!deletePassword || deleting}
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
