# Studio 3 Discover — UI

Mobile-first (375×812px) React web prototype for the Studio 3 Discover social platform. Built with Vite + React Router.

## Design system

- **Typography:** Inter (400, 500, 600, 700)
- **Colors:** Slate palette + glassmorphism (light/dark/bar)
- **Components:** Pill inputs, primary/ghost buttons, pill chips, glass cards, floating bottom nav

## Run

```bash
cd app
npm install
npm run dev
```

Open the dev server (e.g. http://localhost:5173). The UI is constrained to a 375px-wide frame in the center.

## Routes

| Route | Screen |
|-------|--------|
| `/login` | Login |
| `/signup` | Sign up (3 steps) |
| `/home` | Home feed (For You / Following) |
| `/discover` | Discover / Explore |
| `/chat` | Inquiries / Chat |
| `/profile` | Profile (Pieces / Process + Insights) |
| `/post` | New post modal (Piece / Post) |
| `/notifications` | Activity |

## Structure

- `src/index.css` — Design tokens and global styles
- `src/App.jsx` — Router and layout (bottom nav on main app routes)
- `src/components/` — Reusable UI (design, inputs, buttons, layout, feed)
- `src/screens/` — One file per screen

## Design rules (from spec)

- No public engagement counts (likes/saves/followers)
- No trending/popular labels
- Art is hero; generous whitespace; glassmorphism on overlays and floating bar only
- Safe area: bottom nav 24px above bottom; top padding for notch
