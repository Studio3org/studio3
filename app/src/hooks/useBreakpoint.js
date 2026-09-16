import { useEffect, useState } from 'react';

const QUERIES = {
  showRail: '(min-width: 768px)',
  railLabeled: '(min-width: 1264px)',
};

function readState() {
  if (typeof window === 'undefined') return { showRail: false, railLabeled: false };
  return {
    showRail: window.matchMedia(QUERIES.showRail).matches,
    railLabeled: window.matchMedia(QUERIES.railLabeled).matches,
  };
}

/**
 * Two-breakpoint responsive shell state: `showRail` (>=768px, left rail
 * replaces the bottom pill nav) and `railLabeled` (>=1264px, rail grows from
 * icon-only to icons+labels+logo).
 */
export function useBreakpoint() {
  const [state, setState] = useState(readState);

  useEffect(() => {
    const mqRail = window.matchMedia(QUERIES.showRail);
    const mqLabeled = window.matchMedia(QUERIES.railLabeled);
    const update = () => setState({ showRail: mqRail.matches, railLabeled: mqLabeled.matches });
    update();
    mqRail.addEventListener('change', update);
    mqLabeled.addEventListener('change', update);
    return () => {
      mqRail.removeEventListener('change', update);
      mqLabeled.removeEventListener('change', update);
    };
  }, []);

  return state;
}
