import React, { useMemo } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { FloatingPillBottomNav } from './FloatingPillBottomNav';
import { activeTabFromPath, routeForTab } from './navConfig';

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
      onActiveTabChange={(id) => navigate(routeForTab(id))}
    />
  );
}
