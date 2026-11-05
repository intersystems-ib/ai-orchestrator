<script setup lang="ts">
import { ref } from 'vue'
import { consoleUrl } from '../lib/urls'
const visible = ref(false)
</script>

<template>
  <div class="live-console">
    <template v-if="!visible">
      <p>Abre la aplicación real e inicia sesión con tu usuario habitual.</p>
      <button class="demo-link" @click="visible = true">Mostrar consola en esta slide</button>
      <DemoLink>Abrir en otra pestaña</DemoLink>
    </template>
    <iframe v-else :src="consoleUrl" title="Consola real de AI Orchestrator" referrerpolicy="no-referrer" @keydown.stop />
  </div>
</template>
