import { ref, watch } from 'vue'
import { localDay } from './demo.mjs'

function savedDay() {
  try { return sessionStorage.getItem('ai-orchestrator-demo-day') || localDay() }
  catch { return localDay() }
}
export const priceDay = ref(savedDay())
watch(priceDay, day => {
  try { sessionStorage.setItem('ai-orchestrator-demo-day', day) }
  catch { /* The selected date remains usable without browser storage. */ }
})
