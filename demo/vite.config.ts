import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  return {
    server: {
      proxy: {
        '/demo-api': {
          target: env.DEMO_PROXY_TARGET || 'http://127.0.0.1:5173',
          changeOrigin: true,
          rewrite: path => path.replace(/^\/demo-api/, '/api/app'),
        },
      },
    },
  }
})
