import React, { useMemo } from 'react';
import homeSvg from '../../assets/nav/home.svg?raw';
import exploreSvg from '../../assets/nav/explore.svg?raw';
import postSvg from '../../assets/nav/post.svg?raw';
import eventSvg from '../../assets/nav/event.svg?raw';
import bellSvg from '../../assets/nav/bell_icon.svg?raw';
import availableDotSvg from '../../assets/nav/available_dot.svg?raw';
import collectedMarkSvg from '../../assets/nav/collected_mark.svg?raw';

const RAW = {
  home: homeSvg,
  explore: exploreSvg,
  post: postSvg,
  event: eventSvg,
  bell: bellSvg,
  availableDot: availableDotSvg,
  collectedMark: collectedMarkSvg,
};

/** Strips the baked-in hex fill/stroke and fixed width/height from a Flutter
 * `assets/nav/*.svg` export so it can be recolored via CSS `color` and sized
 * by its wrapper, matching how `ColorFilter`-tinted `SvgPicture.asset` works
 * in the real app (lib/widgets/bottom_nav.dart). */
function prepareSvg(raw) {
  return raw
    .replace(/\swidth="[^"]*"/, '')
    .replace(/\sheight="[^"]*"/, '')
    .replace('<svg ', '<svg width="100%" height="100%" ')
    .replace(/(fill|stroke)="#[0-9A-Fa-f]{3,8}"/g, '$1="currentColor"');
}

/**
 * @param {object} props
 * @param {keyof typeof RAW} props.id
 * @param {number} [props.size=24]
 * @param {string} [props.color='currentColor']
 */
export function NavIcon({ id, size = 24, color = 'currentColor', style, ...rest }) {
  const html = useMemo(() => prepareSvg(RAW[id] ?? ''), [id]);
  return (
    <span
      role="img"
      aria-hidden
      style={{ display: 'inline-flex', width: size, height: size, color, flexShrink: 0, ...style }}
      dangerouslySetInnerHTML={{ __html: html }}
      {...rest}
    />
  );
}
