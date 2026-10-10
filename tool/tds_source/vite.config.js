import { defineConfig } from 'vite';

export default defineConfig({
  resolve: { dedupe: ['react', 'react-dom', '@emotion/react'] },
  optimizeDeps: { include: ['react', 'react-dom/client', '@emotion/react', '@toss/tds-mobile', '@toss/tds-mobile-ait'] },
  server: { host: '127.0.0.1', port: 5179, strictPort: true },
});
