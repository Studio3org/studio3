import React, { useCallback, useState } from 'react';
import {
  Bell,
  Bookmark,
  Compass,
  Home,
  MoreHorizontal,
  Plus,
  User,
} from 'lucide-react';

/** @typedef {'more' | 'home' | 'compass' | 'plus' | 'bookmark' | 'bell' | 'profile'} FloatingPillTabId */

/** Center pill only — left “more” and right avatar are separate controls. */
export const CENTER_PILL_TAB_ORDER = /** @type {const} */ ([
  'home',
  'compass',
  'plus',
  'bookmark',
  'bell',
]);

export const FLOATING_PILL_TAB_ORDER = /** @type {const} */ ([
  'more',
  ...CENTER_PILL_TAB_ORDER,
  'profile',
]);

const ICON_MAP = {
  home: Home,
  compass: Compass,
  plus: Plus,
  bookmark: Bookmark,
  bell: Bell,
};

const ARIA_LABEL = {
  more: 'More',
  home: 'Home',
  compass: 'Discover',
  plus: 'Create',
  bookmark: 'Bookmarks',
  bell: 'Notifications',
};

const GLASS_SURFACE =
  'border border-white/[0.08] bg-[#1C1C1E]/[0.88] backdrop-blur-xl backdrop-saturate-150 ' +
  'shadow-[0_8px_24px_rgba(0,0,0,0.32),0_2px_8px_rgba(0,0,0,0.18)]';

const ICON_CLASS = 'h-6 w-6 shrink-0';

const ICON_STROKE_ACTIVE = 2.1;
const ICON_STROKE_INACTIVE = 1.75;

/**
 * Floating bottom nav: separate glass circle (more), pill (main icons), and avatar — matches split “glass” layout.
 *
 * @param {object} props
 * @param {FloatingPillTabId} [props.activeTab] — controlled active tab
 * @param {FloatingPillTabId} [props.defaultActiveTab='home'] — initial tab when uncontrolled
 * @param {(id: FloatingPillTabId) => void} [props.onActiveTabChange]
 * @param {string} [props.avatarSrc]
 * @param {string} [props.avatarAlt='Profile']
 * @param {string} [props.className] — extra classes on the outer wrapper
 */
export function FloatingPillBottomNav({
  activeTab: activeTabProp,
  defaultActiveTab = 'home',
  onActiveTabChange,
  avatarSrc,
  avatarAlt = 'Profile',
  className = '',
}) {
  const [internalTab, setInternalTab] = useState(
    /** @type {FloatingPillTabId} */ (defaultActiveTab),
  );

  const isControlled = activeTabProp !== undefined;
  const activeTab = isControlled ? activeTabProp : internalTab;

  const setActive = useCallback(
    /** @param {FloatingPillTabId} id */
    (id) => {
      if (!isControlled) setInternalTab(id);
      onActiveTabChange?.(id);
    },
    [isControlled, onActiveTabChange],
  );

  const moreActive = activeTab === 'more';
  const profileActive = activeTab === 'profile';

  return (
    <nav
      role="navigation"
      aria-label="Main"
      className={[
        'fixed bottom-4 left-1/2 z-[100] flex max-w-[calc(100vw-1.5rem)] -translate-x-1/2',
        'items-center gap-2.5 sm:gap-3',
        className,
      ]
        .filter(Boolean)
        .join(' ')}
    >
      {/* Left: more — circular */}
      <button
        type="button"
        onClick={() => setActive('more')}
        aria-label={ARIA_LABEL.more}
        aria-pressed={moreActive}
        className={[
          'flex h-14 w-14 shrink-0 items-center justify-center rounded-full transition-shadow',
          GLASS_SURFACE,
          moreActive ? 'ring-2 ring-white/25' : '',
          'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/40',
        ].join(' ')}
      >
        <MoreHorizontal
          className="h-6 w-6 text-white"
          strokeWidth={2}
          aria-hidden
        />
      </button>

      {/* Center: primary icons — pill */}
      <div
        className={[
          'flex shrink-0 items-center justify-center gap-5 rounded-full px-6 py-3.5 sm:gap-6 sm:px-8',
          GLASS_SURFACE,
        ].join(' ')}
      >
        {CENTER_PILL_TAB_ORDER.map((id) => {
          const Icon = ICON_MAP[id];
          const isActive = activeTab === id;
          return (
            <button
              key={id}
              type="button"
              onClick={() => setActive(id)}
              aria-label={ARIA_LABEL[id]}
              aria-current={isActive ? 'page' : undefined}
              className={[
                'flex min-h-10 min-w-10 shrink-0 items-center justify-center rounded-full transition-colors',
                'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/40',
                isActive ? 'text-white' : 'text-white/40 hover:text-white/55',
              ].join(' ')}
            >
              <Icon
                className={ICON_CLASS}
                strokeWidth={isActive ? ICON_STROKE_ACTIVE : ICON_STROKE_INACTIVE}
                aria-hidden
              />
            </button>
          );
        })}
      </div>

      {/* Right: profile — circular */}
      <button
        type="button"
        onClick={() => setActive('profile')}
        aria-label={avatarAlt}
        aria-current={profileActive ? 'page' : undefined}
        className={[
          'relative flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-full transition-shadow',
          GLASS_SURFACE,
          profileActive ? 'ring-2 ring-white/35' : '',
          'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/40',
        ].join(' ')}
      >
        {avatarSrc ? (
          <img
            src={avatarSrc}
            alt=""
            width={56}
            height={56}
            className="h-full w-full object-cover"
          />
        ) : (
          <span
            className={[
              'flex h-10 w-10 items-center justify-center rounded-full',
              profileActive ? 'bg-white/20 text-white' : 'bg-white/10 text-white/45',
            ].join(' ')}
          >
            <User className="h-5 w-5" strokeWidth={1.75} aria-hidden />
          </span>
        )}
      </button>
    </nav>
  );
}
