import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // Absolute base so hashed assets resolve on nested routes like /piece/:id — a relative
  // base makes /piece/abc request /piece/assets/…, which the SPA rewrite answers with HTML.
  base: '/',
});
