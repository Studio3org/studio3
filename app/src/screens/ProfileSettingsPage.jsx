import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/apiClient';
import {
  Store,
  Wallet,
  BarChart3,
  ShoppingBag,
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
  ChevronRight,
} from 'lucide-react';
import './ProfileSettingsPage.css';

export function ProfileSettingsPage() {
  const navigate = useNavigate();
  const { user, logout, refreshUser } = useAuth();

  const [sellerEnabled, setSellerEnabled] = useState(Boolean(user?.isSeller || user?.sellerEnabled));
  const [loadingSeller, setLoadingSeller] = useState(false);
  const [logoutModalOpen, setLogoutModalOpen] = useState(false);

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

  return (
    <div className="settings-page">
      <div className="settings-inner">
        <div className="settings-header">
          <h1 className="settings-title">Profile Settings</h1>
        </div>

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
    </div>
  );
}
