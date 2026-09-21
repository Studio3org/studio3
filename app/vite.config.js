import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // Absolute base so hashed assets resolve on nested routes like /piece/:id.
  base: '/',
  envPrefix: ['VITE_', 'NEXT_PUBLIC_'],
  build: {
    // Production is serving `app/dist` (https://studio3-eta.vercel.app).
    outDir: 'dist',
    emptyOutDir: true,
  },
});
