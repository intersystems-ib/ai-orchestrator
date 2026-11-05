<script setup lang="ts">
import { ref } from 'vue'
import { healthResult } from '../lib/demo.mjs'
const result = ref({ state: 'idle', text: 'Comprobación manual. La presentación funciona aunque el backend esté detenido.' })
const busy = ref(false)
async function check() {
  busy.value = true
  try {
    const response = await fetch('/demo-api/health', { cache: 'no-store', credentials: 'omit', redirect: 'error', signal: AbortSignal.timeout(5000) })
    const body = await response.json().catch(() => null)
    result.value = healthResult(response.status, body)
  } catch { result.value = { state: 'error', text: 'Sin respuesta de la API. Revisa los servicios, puertos y DEMO_PROXY_TARGET.' } }
  finally { busy.value = false }
}
</script>

<template>
  <div class="readiness" :data-state="result.state">
    <p role="status">{{ result.text }}</p>
    <button class="demo-link" :disabled="busy" @click="check">{{ busy ? 'Comprobando…' : 'Comprobar API' }}</button>
  </div>
</template>
