# Conceptos de agentes y demo sencilla con Slidev

[English](README.md) | **Español**

Presentación introductoria en español, organizada en tres bloques:

1. **Conceptos:** agente, herramienta, modelo LLM y servidor MCP.
2. **InterSystems IRIS:** AI Hub, construcción de agentes, conexión de herramientas, policies y servidor MCP.
3. **Demostración:** una consulta de inventario y precios usando AI Orchestrator.

Los conceptos y las capacidades de la plataforma se explican sin anticipar
el caso práctico. El bloque final presenta el inventario y los precios con
un diagrama de sus componentes y conexiones. Las 19 slides incluyen notas para el ponente y un prompt
copiable. El recorrido principal no incluye BPL, envíos, cambios de permisos
ni pruebas de indisponibilidad. El material técnico se conserva como ampliación.

## Arranque de la presentación

Desde la raíz del repositorio:

```powershell
docker compose --profile demo up -d --build demo
```

Abrir [http://localhost:3030](http://localhost:3030). El puerto se cambia con
`DEMO_PORT` en el `.env` raíz. Este servicio no tiene dependencias de arranque:
no inicia IRIS, los modelos ni el frontend y no modifica su configuración.

Para preparar un entorno que esté detenido, iniciar por separado los servicios
habituales, con los puertos disponibles en el equipo:

```powershell
docker compose up -d --build iris iris-demo iris-demo-transport iris-mcp iris-mcp-transport webgateway frontend
# Sólo si se van a utilizar los modelos locales y el equipo dispone de GPU:
docker compose --profile ai up -d llama qwen
```

La demo conserva su guion aunque no haya backend. La comprobación de salud
consulta únicamente `/api/app/health` y no autentica al usuario ni prueba las
inferencias. Un aviso de autenticación no significa que el agente esté listo.

En modo local, se puede editar con recarga de cambios sin reconstruir Docker:

```powershell
cd demo
npm ci
npm run dev
```

Se requiere Node.js **24.11 o posterior**. La imagen Docker incluye Node 24.
Las versiones están fijadas en `package-lock.json`; los overrides de DOMPurify
e image-size aplican las correcciones compatibles detectadas al incorporar Slidev.

## Preparación funcional antes de presentar

1. Iniciar sesión en la consola con un usuario de demostración habilitado.
2. Registrar o revisar un modelo aprobado que ya haya demostrado tool calling.
   Comprobar su conexión con el servidor local o el proveedor elegido.
3. Registrar **iris-demo** en **Servidores MCP** con URL
   `http://iris-demo-transport:8080/mcp` y descubrir sus herramientas. Identificar
   `SearchInventory` del servidor de inventario.
4. Crear o revisar el agente **demo-operaciones**. Seleccionar el modelo,
   aprobarlo, habilitarlo y asignar la búsqueda MCP de inventario.
5. Añadir la policy de auditoría **database-audit** al agente. La autorización
   de usuarios ya es obligatoria en el proyecto.
6. En **Usuarios IA**, habilitar el usuario y asignarle ese agente.
7. Registrar o revisar **iris-mcp-demo**, aprobado y habilitado, con URL
   `http://iris-mcp-transport:8080/mcp` desde el backend Docker. Descubrir sus tools
   y asignar la remota **GetDailyPrices** al agente.
8. Verificar las cotizaciones para la fecha de la demostración. Se pueden
   añadir los siete días recientes de precios ficticios con:

```powershell
Get-Content -Raw demo/scripts/seed-prices.script | docker compose exec -T iris-mcp iris session IRIS
```

El seed no sustituye precios existentes. Conserva nombres y fechas históricas.
Los precios son ejemplos en EUR, no información real de mercado. La fecha
seleccionada en las slides se comparte entre escenarios y se conserva sólo en
la sesión del navegador. Si no hay cotizaciones para ese día, el resultado
correcto es informar de su ausencia.

Instrucciones sugeridas para el agente:

```text
Responde en español. Para datos operativos utiliza las herramientas asignadas.
No inventes stock, precios, fechas ni identificadores. Si no tienes
acceso o faltan datos, indícalo. Para componer inventario y precios, muestra
la fecha de la cotización y explica cualquier ambigüedad entre nombres.
```

La presentación no crea modelos, agentes, usuarios o servidores ni envía prompts
automáticamente. Las acciones del guion se realizan de forma visible desde la
consola. Las respuestas dependen del modelo y de los datos del entorno.

## Guion del ponente

Duración orientativa: **20–25 minutos**, incluyendo la consulta al agente.
Las notas detalladas están en los comentarios de `slides.md` y en la vista de
presentador de Slidev. Se accede a esa vista desde la barra de la presentación
o añadiendo `/presenter` a la URL.

| Bloque | Slides | Objetivo |
|---|---|---|
| Conceptos | 1–6 | Definir los cuatro términos y sus relaciones, sin introducir la demo |
| Plataforma | 7–14 | Explicar el SDK, agentes, herramientas, policies, ejemplos XML y publicación MCP en IRIS con un ejemplo ObjectScript |
| Demostración | 15–18 | Presentar AI Orchestrator y el diagrama del caso, preguntar y comprobar las tools ejecutadas |
| Recapitulación | 19 | Asociar de nuevo cada término con lo observado |

La configuración se prepara **antes** de la sesión. En directo, basta con:

1. Mostrar brevemente `demo-operaciones`, su modelo y sus dos herramientas.
2. Señalar el servidor MCP que ofrece `GetDailyPrices`, si hace falta para
   relacionarlo con la explicación.
3. Abrir el chat, seleccionar el agente y enviar el prompt de la slide 17.
4. Comprobar stock y precio fechado, y mostrar las llamadas correspondientes
   en auditoría. Si falta un dato, explicarlo sin inventar el resultado.

La única consulta del recorrido principal combina el inventario del IRIS de negocio con los
precios del IRIS externo. No cambia stock, permisos ni disponibilidad de servicios.
Para mantener la charla sencilla, reservar formularios de configuración,
producciones BPL y diagnósticos técnicos para preguntas posteriores.

Los enlaces de las slides abren secciones del frontend mediante anclas como
`#models`, `#agents`, `#mcp`, `#chat` y `#audit`. Iniciar sesión sigue siendo
obligatorio. Para mantener una sesión de chat, continuar en la pestaña de la
consola ya abierta. El componente `LiveConsole` sigue disponible si se desea añadir
una slide con la consola embebida como ampliación.

## Ampliación técnica opcional: BPL

1. Importar manualmente `demo/snippets/AgentDemoProcess.cls` en **APP**.
   El archivo sólo declara un proceso; no arranca ni altera la producción.
2. En una producción de demostración, añadir una operación de clase
   `App.Interop.AgentOperation` con nombre **Demo Agent Operation**.
3. Elegir **demo-operaciones** en su único ajuste funcional, `AgentName`.
4. Añadir el proceso `App.Demo.AgentProcess` y un servicio o mecanismo de pruebas
   que le envíe `Ens.StringRequest`.
5. Autorizar al usuario IRIS del job de producción, habitualmente `_Ensemble`,
   para ese agente mediante **Usuarios IA**.
6. Enviar el prompt en `StringValue`. Examinar la respuesta en
   `Ens.StringResponse.StringValue` y la traza en el portal IRIS.
No usar la producción de `iris/tests/bpl-agent/` para una sesión persistente.
Es una prueba técnica desechable, con LLM simulado, que cambia la producción
activa y crea permisos de prueba. El escenario anterior utiliza el modelo real
configurado y conserva el funcionamiento del catálogo.

BPL queda fuera de la presentación introductoria. Este ejemplo se conserva
para una demostración técnica posterior.

## Direcciones y edición

En Docker, las URLs del navegador usan los puertos del `.env` raíz.
Para ejecución con npm, copiar `demo/.env.example` a `demo/.env.local` y ajustar:

| Variable | Uso |
|---|---|
| `VITE_ORCHESTRATOR_URL` | Consola abierta por el navegador |
| `VITE_IRIS_PORTAL_URL` | Portal de la instancia principal |
| `VITE_MCP_PORTAL_URL` | Portal del IRIS externo |
| `DEMO_PROXY_TARGET` | Destino interno del proxy de salud de Slidev |

No introducir contraseñas, API keys, JWT ni tokens en estos archivos o en las
slides. `DEMO_PROXY_TARGET` no es una URL del navegador. Si el presentador usa
otro equipo, ajustar las URLs públicas y el acceso al servicio en la configuración
correspondiente. El puerto Docker de la presentación se publica por defecto
únicamente en loopback.

## Compilación y exportación

```powershell
cd demo
npm test
npm run build
# Para distribuir una versión web sin las notas del ponente:
npm run build:public
# PDF opcional: requiere el navegador de Playwright instalado para Slidev.
npm run export
```

`dist/` contiene la web estática. Su servidor debe resolver las rutas de la SPA.
Los enlaces a la consola siguen necesitando un backend accesible. La comprobación
`/demo-api/health` requiere el proxy de desarrollo o uno equivalente en el servidor
de publicación. Las interacciones del navegador no se conservan como tales en un PDF. Las slides no incluyen fuentes remotas obligatorias.

Referencias de la integración: [Slidev](https://sli.dev/guide/),
[configuración de Vite](https://sli.dev/custom/config-vite),
[estructura de directorios](https://sli.dev/custom/directory-structure) y
[compilación y publicación](https://sli.dev/guide/hosting).

El modelo debe declarar la capacidad real `maxContextTokens` de su endpoint
(Llama 16384 y Qwen 4096 con Compose predeterminado). Configura el presupuesto
de entrada y la reserva de respuesta del agente. El chat tiene las pestañas Chat
y Estadísticas de la conversación y conserva el borrador al alternarlas. Las
acciones MCP son iconos de lista/actualización con ayuda; las tools se consultan
en su modal.
