<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { promptFor } from '../lib/demo.mjs'
import { priceDay as day } from '../lib/state'

const props = withDefaults(defineProps<{ scenario?: string }>(), { scenario: 'inventory' })
const dated = computed(() => ['combined', 'pricing'].includes(props.scenario))
const prompt = computed(() => promptFor(props.scenario, day.value))
const copied = ref(false)
const copyError = ref(false)
watch(prompt, () => { copied.value = false; copyError.value = false })
async function copy() {
  try { await navigator.clipboard.writeText(prompt.value); copied.value = true; copyError.value = false }
  catch { copyError.value = true }
}
</script>

<template>
  <div class="demo-prompt" @keydown.stop>
    <label v-if="dated" class="demo-date">Fecha con cotizaciones disponibles <input v-model="day" type="date" @change="copied = false" /></label>
    <p class="prompt-text">{{ prompt }}</p>
    <div class="demo-prompt-actions">
      <button class="demo-link" :disabled="dated && !day" @click="copy">{{ copied ? 'Prompt copiado' : 'Copiar prompt' }}</button>
      <DemoLink section="chat">Abrir chat</DemoLink>
    </div>
    <p v-if="copyError" class="demo-small" role="status">Selecciona y copia el texto del prompt manualmente.</p>
    <p v-if="dated" class="demo-small">Precios ficticios. Si el día no tiene datos, cambia la fecha o prepara las cotizaciones de la demo.</p>
  </div>
</template>
