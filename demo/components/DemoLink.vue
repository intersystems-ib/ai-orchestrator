<script setup lang="ts">
import { computed } from 'vue'
import { consoleUrl, irisUrl, mcpPortalUrl } from '../lib/urls'
import { consoleLink } from '../lib/demo.mjs'

const props = withDefaults(defineProps<{ section?: string; target?: 'console' | 'iris' | 'mcp' }>(), { section: 'overview', target: 'console' })
const href = computed(() => props.target === 'iris' ? irisUrl : props.target === 'mcp' ? mcpPortalUrl : consoleLink(consoleUrl, props.section))
</script>

<template>
  <a class="demo-link" :href="href" target="_blank" rel="noopener noreferrer"><slot>Abrir consola</slot><span aria-hidden="true"> ↗</span></a>
</template>
