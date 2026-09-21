import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // Absolute base so hashed assets resolve on nested routes like /piece/:id.
  base: '/',
  envPrefix: ['VITE_', 'NEXT_PUBLIC_'],
  build: {
    // Match the Vercel Output Directory (`app/.dist`).
    outDir: '.dist',
    emptyOutDir: true,
  },
});
