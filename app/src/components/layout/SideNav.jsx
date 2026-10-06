import React, { useMemo } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Plus, Settings } from 'lucide-react';
import { NavIcon } from '../icons/NavIcon';
import { ARIA_LABEL, NAV_ICON_ID, NAV_ICON_USER, NAV_ICON_SAVED, NAV_LABEL, NAV_TAB_ORDER, activeTabFromPath, routeForTab } from './navConfig';

// Create gets its own black-circle-plus treatment and sits above Home,
// rather than in its usual NAV_TAB_ORDER slot — everything else keeps that
// order. Mobile's FloatingPillBottomNav is unaffected (still reads
// NAV_TAB_ORDER directly).
const REST_OF_NAV = NAV_TAB_ORDER.filter((id) => id !== 'post');

/**
 * Left rail chrome shown at >=768px in place of the bottom pill nav. Icon-only
 * at 72px (768-1263px); grows to icons+labels+wordmark at 244px (>=1264px).
 *
 * @param {object} props
 * @param {boolean} props.railLabeled
 * @param {string} [props.avatarSrc]
 * @param {string} [props.avatarAlt]
 */
export function SideNav({ railLabeled, avatarSrc, avatarAlt = 'Profile' }) {
  const location = useLocation();
  const navigate = useNavigate();
  const activeTab = useMemo(() => activeTabFromPath(location.pathname), [location.pathname]);
  const isSettingsActive = location.pathname.startsWith('/profile-settings');

  const handleNav = (id) => {
    if (id === 'post') {
      navigate(routeForTab(id), { state: { backgroundLocation: location } });
      return;
    }
    navigate(routeForTab(id));
  };

  return (
    <nav
      role="navigation"
      aria-label="Main"
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        bottom: 0,
        width: railLabeled ? 244 : 72,
        display: 'flex',
        flexDirection: 'column',
        alignItems: railLabeled ? 'stretch' : 'center',
        gap: 4,
        padding: railLabeled ? '24px 12px' : '24px 0',
        background: 'var(--cream-bg)',
        borderRight: '1px solid var(--cream-divider)',
        zIndex: 50,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: railLabeled ? 'flex-start' : 'center',
          padding: railLabeled ? '0 12px 28px' : '0 0 28px',
        }}
      >
        <img
          src="/logo/logo_text_black.png"
          alt="Studio 3"
          height={railLabeled ? 40 : 28}
          style={{ height: railLabeled ? 40 : 28, width: 'auto' }}
        />
      </div>

      <button
        type="button"
        onClick={() => handleNav('post')}
        aria-label={ARIA_LABEL.post}
        aria-current={activeTab === 'post' ? 'page' : undefined}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 14,
          width: railLabeled ? '100%' : 48,
          height: 48,
          padding: railLabeled ? '0 12px' : 0,
          justifyContent: railLabeled ? 'flex-start' : 'center',
          flexShrink: 0,
          marginBottom: 8,
        }}
      >
        <span
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: 32,
            height: 32,
            borderRadius: '50%',
            background: 'var(--cream-cta-fill)',
            flexShrink: 0,
          }}
        >
          <Plus size={18} color="var(--cream-text-inverse)" strokeWidth={2.25} />
        </span>
        {railLabeled && (
          <span style={{ fontFamily: 'var(--font-inter)', fontSize: 15, fontWeight: 400, color: 'var(--cream-text)', whiteSpace: 'nowrap' }}>
            {NAV_LABEL.post}
          </span>
        )}
      </button>

      {REST_OF_NAV.map((id) => {
        const isActive = activeTab === id;
        const isProfile = id === 'profile';
        const isSaved = id === 'saved';
        return (
          <button
            key={id}
            type="button"
            onClick={() => handleNav(id)}
            aria-label={ARIA_LABEL[id]}
            aria-current={isActive ? 'page' : undefined}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 14,
              width: railLabeled ? '100%' : 48,
              height: 48,
              padding: railLabeled ? '0 12px' : 0,
              borderRadius: railLabeled ? 12 : '50%',
              justifyContent: railLabeled ? 'flex-start' : 'center',
              background: isActive ? 'rgba(35,31,27,0.08)' : 'transparent',
              flexShrink: 0,
            }}
          >
            {isProfile ? (
              <span
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: 24,
                  height: 24,
                  borderRadius: '50%',
                  overflow: 'hidden',
                  flexShrink: 0,
                  border: isActive ? '1.5px solid var(--cream-text)' : '1.5px solid transparent',
                  background: 'rgba(35,31,27,0.08)',
                }}
              >
                {avatarSrc ? (
                  <img
                    src={avatarSrc}
                    alt={avatarAlt}
                    width={24}
                    height={24}
                    style={{ objectFit: 'cover', width: '100%', height: '100%' }}
                  />
                ) : (
                  <NAV_ICON_USER size={14} color="var(--cream-text)" strokeWidth={1.75} aria-hidden />
                )}
              </span>
            ) : isSaved ? (
              <NAV_ICON_SAVED
                size={22}
                color={isActive ? 'var(--cream-text)' : 'var(--cream-text-secondary)'}
                strokeWidth={1.75}
              />
            ) : (
              <NavIcon
                id={NAV_ICON_ID[id]}
                size={24}
                color={isActive ? 'var(--cream-text)' : 'var(--cream-text-secondary)'}
              />
            )}
            {railLabeled && (
              <span
                style={{
                  fontFamily: 'var(--font-inter)',
                  fontSize: 15,
                  fontWeight: isActive ? 600 : 400,
                  color: 'var(--cream-text)',
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {NAV_LABEL[id]}
              </span>
            )}
          </button>
        );
      })}

      {/* Bottom-aligned Profile Settings option */}
      <button
        type="button"
        onClick={() => navigate('/profile-settings')}
        aria-label="Profile Settings"
        aria-current={isSettingsActive ? 'page' : undefined}
        style={{
          marginTop: 'auto',
          display: 'flex',
          alignItems: 'center',
          gap: 14,
          width: railLabeled ? '100%' : 48,
          height: 48,
          padding: railLabeled ? '0 12px' : 0,
          borderRadius: railLabeled ? 12 : '50%',
          justifyContent: railLabeled ? 'flex-start' : 'center',
          background: isSettingsActive ? 'rgba(35,31,27,0.08)' : 'transparent',
          flexShrink: 0,
          cursor: 'pointer',
          border: 'none',
        }}
      >
        <Settings
          size={22}
          color={isSettingsActive ? 'var(--cream-text)' : 'var(--cream-text-secondary)'}
          strokeWidth={1.75}
        />
        {railLabeled && (
          <span
            style={{
              fontFamily: 'var(--font-inter)',
              fontSize: 15,
              fontWeight: isSettingsActive ? 600 : 400,
              color: 'var(--cream-text)',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            Profile Settings
          </span>
        )}
      </button>
    </nav>
  );
}

