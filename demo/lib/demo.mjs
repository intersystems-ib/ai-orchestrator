export function httpUrl(value, fallback) {
  try {
    const url = new URL(value || fallback)
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) throw new Error('Invalid URL')
    return url.href
  } catch {
    return fallback
  }
}

export function consoleLink(origin, section = 'overview') {
  const url = new URL(origin)
  url.hash = section
  return url.href
}

export function localDay(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

export function healthResult(status, body) {
  if (status === 401 || status === 403) return { state: 'auth', text: 'Servicio accesible. Se requiere iniciar sesión en la consola.' }
  if (status >= 200 && status < 300 && body?.status === 'ok') return { state: 'ok', text: 'La API responde. Comprueba también modelo, agentes y MCP.' }
  return { state: 'error', text: `La API no confirma disponibilidad (HTTP ${status}).` }
}

export function promptFor(scenario, day) {
  const prompts = {
    inventory: 'Busca los productos cuyo nombre contenga la palabra «Coffee» y muestra su SKU y el stock disponible. Utiliza las herramientas autorizadas, sin inventar datos.',
    pricing: `Consulta las cotizaciones de los productos que contengan «Coffee» para el día ${day}. Muestra nombre, fecha, precio y moneda. Si no hay cotizaciones para ese día, indícalo.`,
    combined: `¿Qué productos de «Coffee» tenemos en el inventario y cuál es su precio para el día ${day}? Devuelve una tabla con producto, SKU, stock, precio y moneda. Utiliza las herramientas disponibles e indica si falta algún dato.`,
    shipments: 'Busca «Rice» en el inventario y utiliza su identificador para consultar los envíos de ese producto. Resume las referencias y cantidades que devuelvan las herramientas.',
    bpl: 'Busca los productos «Coffee» y resume el stock disponible utilizando las herramientas asignadas.',
  }
  return prompts[scenario] || prompts.inventory
}
