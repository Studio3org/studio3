import { User, Bookmark } from 'lucide-react';

/** @typedef {'home' | 'explore' | 'post' | 'event' | 'saved' | 'profile'} NavTabId */

export const NAV_TAB_ORDER = /** @type {const} */ (['home', 'explore', 'post', 'event', 'saved', 'profile']);

export const NAV_ICON_ID = {
  home: 'home',
  explore: 'explore',
  post: 'post',
  event: 'event',
};

export const NAV_ICON_USER = User;
export const NAV_ICON_SAVED = Bookmark;

export const ARIA_LABEL = {
  home: 'Home',
  explore: 'Explore',
  post: 'Create',
  event: 'Events',
  saved: 'Saved',
  profile: 'Profile',
};

export const NAV_LABEL = {
  home: 'Home',
  explore: 'Discover',
  post: 'Create',
  event: 'Events',
  saved: 'Saved',
  profile: 'Profile',
};

const ROUTE_FOR_TAB = {
  home: '/home',
  explore: '/discover',
  post: '/post',
  event: '/event',
  saved: '/saved',
  profile: '/profile',
};

export function routeForTab(id) {
  return ROUTE_FOR_TAB[id] ?? '/home';
}

/** @param {string} pathname */
export function activeTabFromPath(pathname) {
  if (pathname.startsWith('/home')) return 'home';
  if (pathname.startsWith('/discover')) return 'explore';
  if (pathname.startsWith('/post')) return 'post';
  if (pathname.startsWith('/event')) return 'event';
  if (pathname.startsWith('/saved')) return 'saved';
  if (pathname.startsWith('/profile')) return 'profile';
  return 'home';
}

