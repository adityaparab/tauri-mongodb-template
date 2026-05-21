import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/auth': 'http://localhost:3000',
      '/builds': 'http://localhost:3000',
      '/download': 'http://localhost:3000',
      '/generate': 'http://localhost:3000',
      '/health': 'http://localhost:3000',
    },
  },
})
