import { test } from 'node:test'
import assert from 'node:assert/strict'
import { httpUrl, consoleLink, localDay, healthResult, promptFor } from './demo.mjs'

test('demo links cannot execute script URLs or embed credentials', () => {
  const fallback = 'http://localhost:5173'
  for (const value of ['javascript:alert(1)', 'file:///etc/passwd', 'http://user:secret@example.com']) {
    assert.equal(httpUrl(value, fallback), fallback)
  }
  assert.equal(consoleLink('http://localhost:5173/', 'agents'), 'http://localhost:5173/#agents')
})

test('health does not misreport HTML, errors or an authentication gate as ready', () => {
  assert.equal(healthResult(200, {}).state, 'error')
  assert.equal(healthResult(502, {}).state, 'error')
  assert.equal(healthResult(401, {}).state, 'auth')
  assert.equal(healthResult(200, { status: 'ok' }).state, 'ok')
})

test('price scenarios use the selected date rather than stale example prices', () => {
  const day = localDay(new Date(2026, 10, 3, 12))
  assert.equal(day, '2026-11-03')
  assert.ok(promptFor('combined', day).includes(day))
  assert.ok(promptFor('pricing', day).includes(day))
})
