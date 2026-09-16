import React from 'react';
import { NavIcon } from '../icons/NavIcon';
import { ARIA_LABEL, NAV_ICON_ID, NAV_ICON_USER, NAV_ICON_SAVED, NAV_TAB_ORDER } from './navConfig';

/**
 * Floating bottom nav — a single pill capsule with 6 equal icon slots
 * (Home / Explore / Post / Event / Saved / Profile-avatar), matching the real app's
 * `lib/widgets/bottom_nav.dart` exactly.
 *
 * @param {object} props
 * @param {import('./navConfig').NavTabId} [props.activeTab]
 * @param {(id: import('./navConfig').NavTabId) => void} [props.onActiveTabChange]
 * @param {string} [props.avatarSrc]
 * @param {string} [props.avatarAlt='Profile']
 */
export function FloatingPillBottomNav({
  activeTab = 'home',
  onActiveTabChange,
  avatarSrc,
  avatarAlt = 'Profile',
}) {
  return (
    <nav
      role="navigation"
      aria-label="Main"
      style={{
        position: 'fixed',
        bottom: 12,
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 100,
        width: 'min(380px, calc(100% - 20px))',
        height: 64,
        borderRadius: 32,
        background: 'rgba(35, 31, 27, 0.85)',
        backdropFilter: 'blur(24px) saturate(150%)',
        WebkitBackdropFilter: 'blur(24px) saturate(150%)',
        boxShadow: '0 8px 24px rgba(0,0,0,0.32), 0 2px 8px rgba(0,0,0,0.18)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 12px',
      }}
    >
      {NAV_TAB_ORDER.map((id) => {
        const isActive = activeTab === id;
        const isProfile = id === 'profile';
        const isSaved = id === 'saved';
        return (
          <button
            key={id}
            type="button"
            onClick={() => onActiveTabChange?.(id)}
            aria-label={ARIA_LABEL[id]}
            aria-current={isActive ? 'page' : undefined}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 44,
              height: 44,
              borderRadius: '50%',
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
                  boxSizing: 'content-box',
                  border: isActive ? '1.5px solid rgba(250,250,247,0.7)' : '1.5px solid transparent',
                  background: 'rgba(255,255,255,0.1)',
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
                  <NAV_ICON_USER size={14} color={isActive ? '#FAFAF7' : '#8C8880'} strokeWidth={1.75} aria-hidden />
                )}
              </span>
            ) : isSaved ? (
              <NAV_ICON_SAVED size={22} color={isActive ? '#FAFAF7' : '#8C8880'} strokeWidth={1.75} />
            ) : (
              <NavIcon id={NAV_ICON_ID[id]} size={24} color={isActive ? '#FAFAF7' : '#8C8880'} />
            )}
          </button>
        );
      })}
    </nav>
  );
}
