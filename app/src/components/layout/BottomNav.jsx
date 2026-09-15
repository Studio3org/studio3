import React, { useMemo } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { FloatingPillBottomNav } from './FloatingPillBottomNav';

/** @param {string} pathname */
function activeTabFromPath(pathname) {
  if (pathname.startsWith('/home')) return 'home';
  if (pathname.startsWith('/discover')) return 'explore';
  if (pathname.startsWith('/post')) return 'post';
  if (pathname.startsWith('/event')) return 'event';
  if (pathname.startsWith('/profile')) return 'profile';
  return 'home';
}

/**
 * @param {object} [props]
 * @param {string} [props.avatarSrc]
 * @param {string} [props.avatarAlt]
 */
export function BottomNav({ avatarSrc, avatarAlt } = {}) {
  const location = useLocation();
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
          case 'home':
            navigate('/home');
            break;
          case 'explore':
            navigate('/discover');
            break;
          case 'post':
            navigate('/post');
            break;
          case 'event':
            navigate('/event');
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
