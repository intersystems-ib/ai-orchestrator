import { httpUrl } from './demo.mjs'

export const consoleUrl = httpUrl(import.meta.env.VITE_ORCHESTRATOR_URL, 'http://localhost:5173')
export const irisUrl = httpUrl(import.meta.env.VITE_IRIS_PORTAL_URL, 'http://localhost:52773/csp/sys/UtilHome.csp')
export const mcpPortalUrl = httpUrl(import.meta.env.VITE_MCP_PORTAL_URL, 'http://localhost:52774/csp/sys/UtilHome.csp')
