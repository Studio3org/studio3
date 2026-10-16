/// Where a piece or scene opens. Scenes (`type: 'post'`) have their own page; sending them
/// to /piece/:id ("couldn't be found") or the /post composer were both bugs.
export function contentHref(item) {
  if (!item?.id) return '/home';
  const type = item.type ?? item.targetType;
  return type === 'post' ? `/scene/${item.id}` : `/piece/${item.id}`;
}

/** Profile URL for any username (own or someone else's). */
export function profileHref(username) {
  return username ? `/profile/${encodeURIComponent(username)}` : '/profile';
}
