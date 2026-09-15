import React from 'react';
import { Calendar, Compass, Home, SquarePlus, User } from 'lucide-react';

/** @typedef {'home' | 'explore' | 'post' | 'event' | 'profile'} NavTabId */

export const NAV_TAB_ORDER = /** @type {const} */ (['home', 'explore', 'post', 'event', 'profile']);

const ICON_MAP = {
  home: Home,
  explore: Compass,
  post: SquarePlus,
  event: Calendar,
};

const ARIA_LABEL = {
  home: 'Home',
  explore: 'Explore',
  post: 'Create',
  event: 'Events',
  profile: 'Profile',
};

/**
 * Floating bottom nav — a single pill capsule with 5 equal icon slots
 * (Home / Explore / Post / Event / Profile-avatar), matching the real app's
 * `lib/widgets/bottom_nav.dart` exactly: 342x64, radius 32, dark frosted
 * glass (`#231F1B` @ 85%, blur 24), selected icon `#FAFAF7`, inactive
 * `#8C8880`. Sized to the 390px app frame (not the real browser viewport —
 * see index.css's `#root`), so it never overflows on desktop/tablet the way
 * a `100vw`-based size would.
 *
 * @param {object} props
 * @param {NavTabId} [props.activeTab]
 * @param {(id: NavTabId) => void} [props.onActiveTabChange]
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
        width: 'min(342px, calc(min(100vw, 390px) - 20px))',
        height: 64,
        borderRadius: 32,
        background: 'rgba(35, 31, 27, 0.85)',
        backdropFilter: 'blur(24px) saturate(150%)',
        WebkitBackdropFilter: 'blur(24px) saturate(150%)',
        boxShadow: '0 8px 24px rgba(0,0,0,0.32), 0 2px 8px rgba(0,0,0,0.18)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 16px',
      }}
    >
      {NAV_TAB_ORDER.map((id) => {
        const isActive = activeTab === id;
        const isProfile = id === 'profile';
        const Icon = ICON_MAP[id];
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
              width: 48,
              height: 48,
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
                  <User size={14} color={isActive ? '#FAFAF7' : '#8C8880'} strokeWidth={1.75} aria-hidden />
                )}
              </span>
            ) : (
              <Icon
                size={24}
                color={isActive ? '#FAFAF7' : '#8C8880'}
                strokeWidth={isActive ? 2.1 : 1.75}
                aria-hidden
              />
            )}
          </button>
        );
      })}
    </nav>
  );
}
