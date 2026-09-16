import React, { useEffect, useRef, useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ChevronLeft,
  Camera,
  User,
  MapPin,
  Compass,
  Link as LinkIcon,
  Sparkles,
  Loader2,
  Check,
  Globe,
  Tag,
  Plus,
  X,
  ShieldCheck,
  Info,
  Sliders,
  CheckCircle2,
  AlertCircle,
  Wand2,
  Image as ImageIcon,
  Trash2
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { uploadMedia } from '../services/postingApi';
import { changeUsername, checkUsername, updateMe } from '../services/userApi';
import './EditProfilePage.css';

const InstagramIcon = ({ size = 18, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <rect width="20" height="20" x="2" y="2" rx="5" ry="5"/>
    <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/>
    <line x1="17.5" x2="17.51" y1="6.5" y2="6.5"/>
  </svg>
);

const TwitterIcon = ({ size = 18, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <path d="M22 4s-.7 2.1-2 3.4c1.6 10-9.4 17.3-18 11.6 2.2.1 4.4-.6 6-2C3 15.5.5 9.6 3 5c2.2 2.6 5.6 4.1 9 4-.9-4.2 4-6.6 7-3.8 1.1 0 3-1.2 3-1.2z"/>
  </svg>
);

const FALLBACK_ASSETS = {
  banner: '/profile/banner.png',
  avatar: '/profile/avatar.jpg',
};

const PRONOUN_PRESETS = ['she/her', 'he/him', 'they/them', 'she/they', 'he/they'];
const CATEGORY_PRESETS = [
  'Digital Art',
  'Oil & Canvas',
  '3D & Motion',
  'Photography',
  'Illustration',
  'Sculpture',
  'Generative Art',
  'Mixed Media'
];

const BIO_TEMPLATES = [
  'Contemporary artist exploring themes of light, shadow, and digital medium.',
  '3D designer and animator crafting immersive visual worlds.',
  'Fine painter combining traditional oil techniques with modern surrealism.',
  'Visual storyteller capturing urban landscapes and quiet moments.'
];

export function EditProfilePage() {
  const navigate = useNavigate();
  const { user, refreshUser } = useAuth();

  // Form Fields State
  const [name, setName] = useState(user?.name || '');
  const [username, setUsername] = useState(user?.username || '');
  const [bio, setBio] = useState(user?.bio || '');
  const [location, setLocation] = useState(user?.location || '');
  const [pronouns, setPronouns] = useState(user?.pronouns || '');
  const [website, setWebsite] = useState(user?.website || '');
  const [instagram, setInstagram] = useState(user?.instagram || '');
  const [twitter, setTwitter] = useState(user?.twitter || '');
  const [category, setCategory] = useState(user?.category || 'Digital Art');
  const [bannerAutoRule, setBannerAutoRule] = useState(user?.bannerAutoRule || 'most_saved');

  // Tags State
  const [tags, setTags] = useState(user?.tags || ['Abstract', 'Digital', 'NFT']);
  const [tagInput, setTagInput] = useState('');

  // Media State
  const [avatarFile, setAvatarFile] = useState(null);
  const [avatarPreview, setAvatarPreview] = useState(user?.profilePhotoUrl || null);
  const [coverFile, setCoverFile] = useState(null);
  const [coverPreview, setCoverPreview] = useState(user?.coverPhotoUrl || null);

  // Status & Feedback State
  const [saving, setSaving] = useState(false);
  const [locating, setLocating] = useState(false);
  const [error, setError] = useState('');
  const [successToast, setSuccessToast] = useState(false);
  const [activeTab, setActiveTab] = useState('identity');
  const [usernameStatus, setUsernameStatus] = useState(null); // 'checking' | 'available' | 'taken'
  const [usernameMessage, setUsernameMessage] = useState(null);

  const avatarInputRef = useRef(null);
  const coverInputRef = useRef(null);
  const usernameCheckId = useRef(0);

  const usernameChanged = username.trim() && username.trim() !== user?.username;

  // Live username-availability check while editing, mirroring the app's
  // debounced check — excludes the caller's own current username via
  // `for_user_id=me` so re-typing your existing handle doesn't show "taken".
  useEffect(() => {
    if (!usernameChanged || username.trim().length < 3) {
      setUsernameStatus(null);
      return;
    }
    const id = ++usernameCheckId.current;
    setUsernameStatus('checking');
    const t = setTimeout(async () => {
      try {
        const result = await checkUsername(username.trim());
        if (usernameCheckId.current !== id) return;
        setUsernameStatus(result.available ? 'available' : 'taken');
        setUsernameMessage(result.message || null);
      } catch {
        if (usernameCheckId.current !== id) return;
        setUsernameStatus(null);
      }
    }, 400);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [username, usernameChanged]);

  if (!user) return null;

  // Profile completion calculation
  const completionPercentage = useMemo(() => {
    let score = 0;
    const total = 7;
    if (name.trim()) score++;
    if (avatarPreview) score++;
    if (coverPreview) score++;
    if (bio.trim()) score++;
    if (location.trim()) score++;
    if (website.trim()) score++;
    if (tags.length > 0) score++;
    return Math.round((score / total) * 100);
  }, [name, avatarPreview, coverPreview, bio, location, website, tags]);

  // Handle Geolocation API
  const handleUseCurrentLocation = () => {
    if (!navigator.geolocation) {
      setError('Geolocation is not supported by your browser.');
      return;
    }
    setLocating(true);
    setError('');
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`
          );
          const data = await res.json();
          const city = data?.address?.city || data?.address?.town || data?.address?.county || '';
          const country = data?.address?.country || '';
          const formatted = [city, country].filter(Boolean).join(', ');
          setLocation(formatted || `${pos.coords.latitude.toFixed(2)}, ${pos.coords.longitude.toFixed(2)}`);
        } catch {
          setLocation(`${pos.coords.latitude.toFixed(2)}, ${pos.coords.longitude.toFixed(2)}`);
        } finally {
          setLocating(false);
        }
      },
      () => {
        setError('Location permission denied.');
        setLocating(false);
      }
    );
  };

  // Tags management
  const handleAddTag = (e) => {
    if ((e.key === 'Enter' || e.key === ',') && tagInput.trim()) {
      e.preventDefault();
      const newTag = tagInput.trim().replace(/^#/, '');
      if (!tags.includes(newTag) && tags.length < 8) {
        setTags([...tags, newTag]);
      }
      setTagInput('');
    }
  };

  const handleRemoveTag = (tagToRemove) => {
    setTags(tags.filter((t) => t !== tagToRemove));
  };

  // Save profile changes
  const handleSave = async () => {
    if (saving) return;
    if (usernameChanged && usernameStatus === 'taken') {
      setActiveTab('identity');
      setError(usernameMessage || 'That username is taken.');
      return;
    }
    setSaving(true);
    setError('');
    try {
      if (usernameChanged) {
        await changeUsername(username.trim());
      }

      let profilePhotoUrl = user.profilePhotoUrl;
      if (avatarFile) profilePhotoUrl = await uploadMedia(avatarFile, 'profile');

      let coverPhotoUrl = user.coverPhotoUrl;
      if (coverFile) coverPhotoUrl = await uploadMedia(coverFile, 'cover');

      await updateMe({
        name: name.trim(),
        bio: bio.trim(),
        location: location.trim(),
        pronouns: pronouns.trim(),
        website: website.trim(),
        instagram: instagram.trim(),
        twitter: twitter.trim(),
        category,
        tags,
        bannerAutoRule,
        profilePhotoUrl,
        coverPhotoUrl,
      });

      await refreshUser();
      setSuccessToast(true);
      setTimeout(() => {
        setSuccessToast(false);
        navigate(-1);
      }, 1200);
    } catch (e) {
      setError(e?.message || 'Failed to update profile. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="edit-profile-page">
      {/* Top sticky Header Bar */}
      <div className="edit-profile-bar">
        <div className="edit-bar-left">
          <button
            type="button"
            className="edit-profile-back"
            onClick={() => navigate(-1)}
            aria-label="Back"
          >
            <ChevronLeft size={20} />
          </button>
          <div className="edit-bar-title-group">
            <h1 className="edit-profile-title">Edit Profile</h1>
            <span className="edit-completion-badge">
              <span className="edit-completion-dot" style={{ background: completionPercentage === 100 ? '#2e7d32' : '#d97706' }} />
              {completionPercentage}% Complete
            </span>
          </div>
        </div>

        <button
          type="button"
          className="edit-profile-save-btn"
          disabled={saving}
          onClick={handleSave}
        >
          {saving ? <Loader2 size={16} className="app-spin" /> : <Check size={16} />}
          <span>{saving ? 'Saving...' : 'Save Profile'}</span>
        </button>
      </div>

      <div className="edit-profile-container">
        {error && (
          <div className="edit-error-banner">
            <AlertCircle size={16} />
            <span>{error}</span>
          </div>
        )}

        {/* Hero Media Card */}
        <div className="edit-hero-card">
          <input
            ref={coverInputRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) {
                setCoverFile(f);
                setCoverPreview(URL.createObjectURL(f));
              }
            }}
          />
          <div className="edit-cover-wrapper">
            <img
              className="edit-cover-img"
              src={coverPreview || FALLBACK_ASSETS.banner}
              alt="Cover Banner"
            />
            <div className="edit-cover-overlay-bar">
              <button
                type="button"
                className="edit-media-action-btn"
                onClick={() => coverInputRef.current?.click()}
              >
                <Camera size={15} />
                <span>{coverPreview ? 'Change Cover' : 'Upload Cover'}</span>
              </button>
              {coverPreview && (
                <button
                  type="button"
                  className="edit-media-action-btn danger"
                  onClick={() => {
                    setCoverFile(null);
                    setCoverPreview(null);
                  }}
                >
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          </div>

          {/* Avatar floating preview */}
          <input
            ref={avatarInputRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) {
                setAvatarFile(f);
                setAvatarPreview(URL.createObjectURL(f));
              }
            }}
          />
          <div className="edit-avatar-wrapper">
            <div
              className="edit-avatar-circle"
              onClick={() => avatarInputRef.current?.click()}
            >
              <img
                className="edit-avatar-img"
                src={avatarPreview || FALLBACK_ASSETS.avatar}
                alt="Profile Avatar"
              />
              <div className="edit-avatar-overlay">
                <Camera size={20} />
              </div>
            </div>
            <div className="edit-avatar-info">
              <span className="edit-avatar-name">{name || 'Your Name'}</span>
              <span className="edit-avatar-handle">@{username || 'handle'}</span>
            </div>
          </div>
        </div>

        {/* Section Tabs Navigation */}
        <div className="edit-tabs-nav">
          <button
            type="button"
            className={`edit-tab-btn ${activeTab === 'identity' ? 'active' : ''}`}
            onClick={() => setActiveTab('identity')}
          >
            <User size={15} />
            <span>Identity</span>
          </button>
          <button
            type="button"
            className={`edit-tab-btn ${activeTab === 'bio' ? 'active' : ''}`}
            onClick={() => setActiveTab('bio')}
          >
            <Sliders size={15} />
            <span>Bio & Socials</span>
          </button>
          <button
            type="button"
            className={`edit-tab-btn ${activeTab === 'banner' ? 'active' : ''}`}
            onClick={() => setActiveTab('banner')}
          >
            <Sparkles size={15} />
            <span>Hero & Banner</span>
          </button>
        </div>

        {/* TAB 1: IDENTITY */}
        {activeTab === 'identity' && (
          <div className="edit-tab-content">
            <div className="edit-form-card">
              <div className="edit-card-header">
                <h2 className="edit-card-title">Basic Information</h2>
                <p className="edit-card-subtitle">Your public identity visible across Studio 3</p>
              </div>

              <div className="edit-field-group">
                {/* Full Name */}
                <div className="edit-field">
                  <div className="edit-field-label">
                    <span>Display Name</span>
                    <span className="edit-field-count">{name.length}/50</span>
                  </div>
                  <div className="edit-input-wrapper">
                    <User size={18} className="edit-input-icon" />
                    <input
                      type="text"
                      maxLength={50}
                      className="edit-input has-icon"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      placeholder="e.g. Alex Vance"
                    />
                  </div>
                </div>

                {/* Username */}
                <div className="edit-field">
                  <div className="edit-field-label">
                    <span>Username</span>
                    {usernameChanged && (
                      <span className="edit-field-notice">30-day change policy</span>
                    )}
                  </div>
                  <div className="edit-input-wrapper">
                    <span className="edit-input-prefix">@</span>
                    <input
                      type="text"
                      className="edit-input has-prefix"
                      value={username}
                      onChange={(e) => setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g, ''))}
                      placeholder="username"
                    />
                  </div>
                  {usernameStatus && (
                    <span
                      className="edit-username-status"
                      style={{
                        color:
                          usernameStatus === 'available' ? '#2e7d32' : usernameStatus === 'taken' ? '#d32f2f' : 'var(--edit-secondary)',
                      }}
                    >
                      {usernameStatus === 'checking' && 'Checking availability…'}
                      {usernameStatus === 'available' && 'Username is available'}
                      {usernameStatus === 'taken' && (usernameMessage || 'That username is taken')}
                    </span>
                  )}
                </div>

                {/* Pronouns Picker */}
                <div className="edit-field">
                  <label className="edit-field-label">Pronouns</label>
                  <div className="edit-pronouns-pills">
                    {PRONOUN_PRESETS.map((p) => (
                      <button
                        key={p}
                        type="button"
                        className={`edit-pill-btn ${pronouns === p ? 'selected' : ''}`}
                        onClick={() => setPronouns(pronouns === p ? '' : p)}
                      >
                        {p}
                      </button>
                    ))}
                  </div>
                  <input
                    type="text"
                    className="edit-input mt-8"
                    value={pronouns}
                    onChange={(e) => setPronouns(e.target.value)}
                    placeholder="Or type custom pronouns (e.g. xe/them)"
                  />
                </div>

                {/* Primary Art Medium Category */}
                <div className="edit-field">
                  <label className="edit-field-label">Primary Discipline</label>
                  <div className="edit-category-grid">
                    {CATEGORY_PRESETS.map((cat) => (
                      <div
                        key={cat}
                        className={`edit-category-card ${category === cat ? 'active' : ''}`}
                        onClick={() => setCategory(cat)}
                      >
                        <span>{cat}</span>
                        {category === cat && <CheckCircle2 size={14} className="edit-category-check" />}
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 2: BIO & SOCIALS */}
        {activeTab === 'bio' && (
          <div className="edit-tab-content">
            <div className="edit-form-card">
              <div className="edit-card-header">
                <h2 className="edit-card-title">Artist Bio</h2>
                <p className="edit-card-subtitle">Tell collectors and creators about your art style & story</p>
              </div>

              <div className="edit-field-group">
                {/* Bio text area */}
                <div className="edit-field">
                  <div className="edit-field-label">
                    <span>Bio</span>
                    <span className={`edit-field-count ${bio.length > 230 ? 'warning' : ''}`}>
                      {bio.length}/250
                    </span>
                  </div>
                  <textarea
                    className="edit-textarea"
                    maxLength={250}
                    value={bio}
                    onChange={(e) => setBio(e.target.value)}
                    placeholder="Write a brief artist statement or bio..."
                  />

                  {/* Bio Quick Suggestions */}
                  <div className="edit-templates-box">
                    <div className="edit-templates-header">
                      <Wand2 size={13} />
                      <span>Quick Bio Starters</span>
                    </div>
                    <div className="edit-templates-list">
                      {BIO_TEMPLATES.map((tmpl, idx) => (
                        <button
                          key={idx}
                          type="button"
                          className="edit-template-pill"
                          onClick={() => setBio(tmpl)}
                        >
                          "{tmpl.slice(0, 42)}..."
                        </button>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Location */}
                <div className="edit-field">
                  <label className="edit-field-label">Location</label>
                  <div className="edit-location-row">
                    <div className="edit-input-wrapper" style={{ flex: 1 }}>
                      <MapPin size={18} className="edit-input-icon" />
                      <input
                        type="text"
                        className="edit-input has-icon"
                        value={location}
                        onChange={(e) => setLocation(e.target.value)}
                        placeholder="e.g. Berlin, Germany or Tokyo"
                      />
                    </div>
                    <button
                      type="button"
                      className="edit-location-btn"
                      disabled={locating}
                      onClick={handleUseCurrentLocation}
                    >
                      {locating ? <Loader2 size={15} className="app-spin" /> : <Compass size={15} />}
                      <span>{locating ? 'Locating...' : 'Detect'}</span>
                    </button>
                  </div>
                </div>

                {/* Website & Links */}
                <div className="edit-field">
                  <label className="edit-field-label">Website / Portfolio Link</label>
                  <div className="edit-input-wrapper">
                    <Globe size={18} className="edit-input-icon" />
                    <input
                      type="url"
                      className="edit-input has-icon"
                      value={website}
                      onChange={(e) => setWebsite(e.target.value)}
                      placeholder="https://yourportfolio.art"
                    />
                  </div>
                </div>

                {/* Social Handles */}
                <div className="edit-field-row-2">
                  <div className="edit-field">
                    <label className="edit-field-label">Instagram</label>
                    <div className="edit-input-wrapper">
                      <InstagramIcon size={18} className="edit-input-icon" />
                      <input
                        type="text"
                        className="edit-input has-icon"
                        value={instagram}
                        onChange={(e) => setInstagram(e.target.value)}
                        placeholder="@username"
                      />
                    </div>
                  </div>

                  <div className="edit-field">
                    <label className="edit-field-label">Twitter / X</label>
                    <div className="edit-input-wrapper">
                      <TwitterIcon size={18} className="edit-input-icon" />
                      <input
                        type="text"
                        className="edit-input has-icon"
                        value={twitter}
                        onChange={(e) => setTwitter(e.target.value)}
                        placeholder="@handle"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: HERO & BANNER */}
        {activeTab === 'banner' && (
          <div className="edit-tab-content">
            <div className="edit-form-card">
              <div className="edit-card-header">
                <h2 className="edit-card-title">Banner Auto-Display Rule</h2>
                <p className="edit-card-subtitle">Choose how artwork dynamically pins to your profile header</p>
              </div>

              <div className="edit-banner-rules">
                <div
                  className={`edit-rule-option ${bannerAutoRule === 'most_saved' ? 'selected' : ''}`}
                  onClick={() => setBannerAutoRule('most_saved')}
                >
                  <div className="edit-rule-radio">
                    {bannerAutoRule === 'most_saved' && <div className="edit-rule-dot" />}
                  </div>
                  <div className="edit-rule-text">
                    <div className="edit-rule-title">Most Saved Artwork</div>
                    <div className="edit-rule-desc">Automatically showcases your highest saved piece in the profile banner</div>
                  </div>
                </div>

                <div
                  className={`edit-rule-option ${bannerAutoRule === 'most_recent' ? 'selected' : ''}`}
                  onClick={() => setBannerAutoRule('most_recent')}
                >
                  <div className="edit-rule-radio">
                    {bannerAutoRule === 'most_recent' && <div className="edit-rule-dot" />}
                  </div>
                  <div className="edit-rule-text">
                    <div className="edit-rule-title">Most Recent Post</div>
                    <div className="edit-rule-desc">Displays your newest published creation on your profile header</div>
                  </div>
                </div>

                <div
                  className={`edit-rule-option ${bannerAutoRule === 'none' ? 'selected' : ''}`}
                  onClick={() => setBannerAutoRule('none')}
                >
                  <div className="edit-rule-radio">
                    {bannerAutoRule === 'none' && <div className="edit-rule-dot" />}
                  </div>
                  <div className="edit-rule-text">
                    <div className="edit-rule-title">Static Cover Image</div>
                    <div className="edit-rule-desc">Use your uploaded cover photo as a constant profile banner</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Profile Tags / Discipline Badges */}
            <div className="edit-form-card">
              <div className="edit-card-header">
                <h2 className="edit-card-title">Discipline & Style Tags</h2>
                <p className="edit-card-subtitle">Add up to 8 keywords representing your aesthetic style</p>
              </div>

              <div className="edit-tags-container">
                <div className="edit-tags-list">
                  {tags.map((tag) => (
                    <span key={tag} className="edit-tag-chip">
                      #{tag}
                      <button
                        type="button"
                        className="edit-tag-remove"
                        onClick={() => handleRemoveTag(tag)}
                      >
                        <X size={12} />
                      </button>
                    </span>
                  ))}
                </div>

                {tags.length < 8 && (
                  <div className="edit-input-wrapper mt-12">
                    <Tag size={16} className="edit-input-icon" />
                    <input
                      type="text"
                      className="edit-input has-icon"
                      value={tagInput}
                      onChange={(e) => setTagInput(e.target.value)}
                      onKeyDown={handleAddTag}
                      placeholder="Type a tag and press Enter (e.g. oil, abstract)"
                    />
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Profile Settings Quick Link Footer */}
        <div className="edit-settings-footer-card" onClick={() => navigate('/profile-settings')}>
          <div className="edit-settings-footer-left">
            <ShieldCheck size={22} className="edit-settings-icon" />
            <div>
              <div className="edit-settings-footer-title">Account & Security Settings</div>
              <div className="edit-settings-footer-sub">Manage password, privacy, email & notifications</div>
            </div>
          </div>
          <ChevronLeft size={18} style={{ transform: 'rotate(180deg)' }} />
        </div>
      </div>

      {/* Success Toast Notification */}
      {successToast && (
        <div className="edit-success-toast">
          <Check size={16} />
          <span>Profile saved successfully!</span>
        </div>
      )}
    </div>
  );
}
