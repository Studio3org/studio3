import React, { useMemo } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { FloatingPillBottomNav } from './FloatingPillBottomNav';
import { useSession } from '../../lib/session';

/** @param {string} pathname */
function activeTabFromPath(pathname) {
  if (pathname.startsWith('/home')) return 'home';
  if (pathname.startsWith('/discover')) return 'compass';
  if (pathname.startsWith('/post')) return 'plus';
  if (pathname.startsWith('/notifications')) return 'bell';
  if (pathname.startsWith('/profile')) return 'profile';
  if (pathname.startsWith('/saved')) return 'bookmark';
  if (pathname.startsWith('/settings')) return 'more';
  return 'home';
}

/**
 * @param {object} [props]
 * @param {string} [props.avatarAlt]
 */
export function BottomNav({ avatarAlt } = {}) {
  const location = useLocation();
  const { user } = useSession();
  const avatarSrc = user?.profilePhotoUrl ?? undefined;
  const navigate = useNavigate();

  const activeTab = useMemo(
    () => activeTabFromPath(location.pathname),
    [location.pathname],
  );

  return (
    <FloatingPillBottomNav
      activeTab={activeTab}
      avatarSrc={avatarSrc}
      avatarAlt={avatarAlt}
      onActiveTabChange={(id) => {
        switch (id) {
          case 'more':
            navigate('/settings');
            break;
          case 'home':
            navigate('/home');
            break;
          case 'compass':
            navigate('/discover');
            break;
          case 'plus':
            navigate('/post');
            break;
          case 'bookmark':
            navigate('/saved');
            break;
          case 'bell':
            navigate('/notifications');
            break;
          case 'profile':
            navigate('/profile');
            break;
          default:
            break;
        }
      }}
    />
  );
}
