import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// 由 Rust 挂在 /ui，静态资源路径需带此前缀
export default defineConfig({
  plugins: [react()],
  base: '/ui/',
  server: {
    port: 5173,
    proxy: {
      '/health': { target: 'http://127.0.0.1:8080', changeOrigin: true },
      '/db-version': { target: 'http://127.0.0.1:8080', changeOrigin: true },
      '/greeting': { target: 'http://127.0.0.1:8080', changeOrigin: true },
    },
  },
});
