# AI Governance Hub

[English](README.md) | **Español**

MVP de gobierno y composición de agentes sobre el
[ObjectScript SDK de InterSystems AI Hub](https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk).
La arquitectura Docker incluye IRIS, Web Gateway, una consola React servida
por Nginx y dos servidores locales llama.cpp opcionales.

## Capacidades

- Catálogo gobernado de modelos con configuración de proveedor integrada.
- Visualización y edición desde la consola de todos los datos de modelos,
  agentes y tools, incluidas sus asignaciones dinámicas.
- Descubrimiento de los métodos publicados por todas las clases de aplicación
  compiladas en el namespace que extienden `%AI.Tool`.
- Selección dinámica de los métodos disponibles para cada agente.
- Chat multi-turno para probar cualquier agente aprobado, con sesiones y
  mensajes persistidos en IRIS.
- Enrutamiento obligatorio de cada inferencia por una producción de
  interoperabilidad, conservando petición y respuesta en el Message Bank.
- Allow-list de usuarios IRIS y policy `%AI.Policy.Authorization` obligatoria
  tanto para iniciar chats como para descubrir o ejecutar tools.
- Registro de policies de autorización, auditoría y descubrimiento, validando
  el contrato nativo correspondiente de AI Hub.
- Asignaciones agente→tool y tool→policy almacenadas íntegramente en IRIS y
  modificables sin recompilar ObjectScript.
- Auditoría persistente de llamadas a tools, con agente, argumentos, resultado,
  duración y estado de ejecución.
- Factoría que materializa cada definición como `%AI.Agent`, registra solamente
  los métodos permitidos con `ToolManager.AddTool()` y configura sus policies.
- Ciclo de vida `draft`, `approved`, `suspended` y `retired`.

### Resumen funcional

| Área | Características |
|---|---|
| Modelos | Catálogo de modelos comerciales y locales, conexión, aprobación y activación en una única entidad |
| Agentes | Selección de modelo, system prompt, temperatura, máximo de iteraciones, tools y policies |
| Tools | Descubrimiento de métodos publicados por clases que extienden `%AI.Tool` y asignación por agente |
| Policies | Autorización obligatoria, descubrimiento y auditorías aplicables dinámicamente a cada tool |
| Identidad | Autenticación JWT de IRIS, allow-list de usuarios y autorización usuario→agente |
| Chat | Conversaciones y mensajes persistidos, selección de agente e invocación real mediante AI Hub |
| Auditoría | Registro persistente de agente, tool, argumentos, resultado, duración y errores |
| Demo | Inventario, envíos y líneas de producto persistentes; búsqueda iFind, alta acumulativa y consultas mediante cuatro tools |

Toda la configuración funcional se resuelve en IRIS. Docker Compose únicamente
define la infraestructura ejecutable —IRIS, Web Gateway, frontend y servidores
LLM locales—; no es la fuente de configuración de modelos, agentes, tools,
policies o autorizaciones.

```text
clases %AI.Tool ──> %Discover() ──> catálogo IRIS
                                           │
                              asignación agente→método
                                           │
                              asignación tool→audit policy
                                           │
modelo + configuración de agente ──────────┤
                                           ▼
API REST ──> Business Service ──> Business Operation ──> %AI.Agent
                │                       │                      │
                └──── mensajes IRIS ────┴──── tools/policies ─┘
```

## Producción de interoperabilidad

`App.Interop.Production` es la ruta obligatoria para cualquier llamada a un
LLM. La API crea un `App.Interop.Message.ChatRequest` y lo entrega de forma
síncrona al Business Service `AI Governance API Service`. Este reenvía el
mensaje al Business Operation `AI Hub LLM Operation`, único componente que
materializa y ejecuta el agente mediante AI Hub.

IRIS persiste las cabeceras y los cuerpos de petición y respuesta en el Message
Bank. Cada petición incorpora un `RequestId`, usuario JWT, agente, conversación,
propósito y fecha. La respuesta conserva estado, error, duración y resultado.
Ese mismo `RequestId` se propaga a los mensajes funcionales del chat y a las
auditorías de tools, permitiendo correlacionar los niveles HTTP,
interoperabilidad, agente y herramienta.

La identidad no se obtiene de `$username` dentro de la operación: el sujeto JWT
validado por la API viaja explícitamente en el mensaje y se instala en el
contexto local del job antes de aplicar las policies. La producción queda
configurada para arranque automático durante el bootstrap.

## Configuración segura de modelos

`App.Governance.Model` conserva exclusivamente los metadatos gobernados de cada
modelo:

- identidad y nombre visible;
- proveedor AI Hub;
- identificador comercial o alias local del modelo;
- estado de aprobación y activación.

Los campos de conexión (`apiKey`, `baseUrl`, `region`, etc.) se almacenan en
`%ConfigStore.Configuration`, no como propiedades o columnas de
`App.Governance.Model`. Cada registro utiliza internamente una FQN estable con
el formato `APP.AI.MODEL.model-<id>`. Esta relación se deriva del ID del modelo:
no existe un campo `ConfigName` ni una configuración que el usuario tenga que
administrar por separado.

La API y el formulario siguen exponiendo los mismos campos. `Create`, `Update`
y `ListJSON` de `App.Governance.Model` escriben y leen Config Store de forma
transparente, mientras el agente selecciona el modelo gobernado y añade
únicamente su comportamiento: prompt, temperatura, iteraciones, tools y
policies.

El material secreto sigue perteneciendo a Secure Wallet. La configuración del
modelo guarda en Config Store referencias `secret://...`, nunca API keys o
tokens en texto plano. Al materializar el agente, IRIS pide a Config Store los
detalles con resolución de secretos habilitada.

La versión actual reconoce los siguientes proveedores y campos:

| Provider ID | Proveedor | Campos de conexión contemplados |
|---|---|---|
| `openai` | OpenAI | `apiKey`, `baseUrl`, `orgId` |
| `anthropic` | Anthropic | `apiKey`, `baseUrl`, `version` |
| `gemini` | Google Gemini | `apiKey` |
| `bedrock` | AWS Bedrock | `region`, `bearerToken` |
| `vertex` | Google Vertex | `projectId`, `region`, `serviceAccountPath` |
| `meta` | Meta Llama | `apiKey` |
| `nim` | NVIDIA NIM y endpoints OpenAI-compatible locales | `baseUrl`, `apiKey` |
| `xai` | xAI | `apiKey` |
| `deepseek` | DeepSeek | `apiKey`, `baseUrl` |
| `kimi` | Kimi / Moonshot AI | `apiKey`, `baseUrl` |
| `openrouter` | OpenRouter | `apiKey`, `siteUrl`, `siteName`, `baseUrl` |
| `ollama` | Ollama | `baseUrl` |

La tabla refleja los campos que conoce el catálogo de esta versión. Los campos
obligatorios concretos, URLs y mecanismos de credenciales dependen del
proveedor y deben validarse contra la versión del SDK de AI Hub instalada.

### Ejemplo: OpenAI

El modelo se registra desde la consola o mediante `POST /api/app/models`:

```json
{
  "name": "openai-production",
  "displayName": "OpenAI producción",
  "provider": "openai",
  "modelId": "modelo-habilitado-en-la-cuenta",
  "apiKey": "secret://openai-production-api-key",
  "baseUrl": "https://api.openai.com/v1",
  "orgId": "org-opcional",
  "status": "approved",
  "enabled": true
}
```

### Ejemplo: Anthropic

```json
{
  "name": "anthropic-production",
  "displayName": "Anthropic producción",
  "provider": "anthropic",
  "modelId": "modelo-habilitado-en-la-cuenta",
  "apiKey": "secret://anthropic-production-api-key",
  "baseUrl": "https://api.anthropic.com",
  "version": "version-soportada-por-el-proveedor",
  "status": "approved",
  "enabled": true
}
```

### Modelos locales incluidos

Los dos servidores llama.cpp del perfil `ai` exponen una API compatible con
OpenAI dentro de la red de Docker. Los modelos se registran directamente con
su configuración:

```json
{
  "name": "llama-3.1-8b-instruct",
  "provider": "nim",
  "modelId": "llama-3.1-8b-instruct",
  "baseUrl": "http://llama:8000/v1",
  "apiKey": "not-needed"
}
```

```json
{
  "name": "qwen3.5-9b",
  "provider": "nim",
  "modelId": "qwen3.5-9b",
  "baseUrl": "http://qwen:8000/v1",
  "apiKey": "not-needed"
}
```

El puerto es `8000` porque la comunicación se realiza entre contenedores. Los
puertos `8000` y `8001` publicados en el host se usan solamente para acceder a
Llama y Qwen respectivamente desde fuera de la red Docker.

Estos registros son datos del namespace y no forman parte de la imagen ni del
bootstrap. En una base de datos nueva deben registrarse de nuevo desde la
plataforma.

### Resolución en tiempo de ejecución

Al crear una sesión, `App.AIHub.AgentFactory`:

1. carga el agente aprobado desde `App_Governance.Agent`;
2. resuelve su modelo aprobado en `App_Governance.Model`;
3. obtiene de `%ConfigStore.Configuration` los detalles de conexión asociados
   al ID del modelo;
4. solicita a Config Store la resolución de sus referencias `secret://`;
5. crea el `%AI.Provider` indicado y ejecuta `ValidateConfig()`;
6. configura el `%AI.Agent` y adjunta únicamente las tools y policies
   autorizadas.

La plataforma rechaza valores directos en `ApiKey` y `BearerToken`: deben ser
referencias `secret://`, salvo el valor explícito `not-needed` de los modelos
locales. Si un secreto no puede resolverse o `ValidateConfig()` falla, el
agente no se materializa y la llamada se rechaza antes de iniciar el chat.

## Arranque

La solución requiere la imagen de InterSystems IRIS con AI Hub configurada en
`docker-compose.yml`:

```text
docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.2.0AI.162.0
```

```powershell
Copy-Item .env.example .env
docker compose up --build
```

Para iniciar también los modelos locales:

```powershell
docker compose --profile ai up -d --build
```

El bootstrap sincroniza el catálogo de `%AI.Tool` y prepara los recursos
técnicos de la plataforma. Los modelos, su configuración de proveedor, los
agentes y sus asignaciones se administran como datos persistentes en IRIS; no
se crean desde clases ObjectScript con valores de configuración codificados.

El perfil `ai` inicia simultáneamente dos servidores OpenAI-compatible:

- Llama en <http://localhost:8000>.
- Qwen 3.5 9B en <http://localhost:8001>, cargando
  `models/Qwen3.5-9B-Q5_K_M.gguf` y usando el alias `qwen3.5-9b`.

- UI: <http://localhost:5173>
- API: <http://localhost:8080/api/app/health>
- Portal de IRIS: <http://localhost:52773/csp/sys/UtilHome.csp>

La configuración de desarrollo usa el endpoint JWT nativo de IRIS. `POST
/api/app/login` valida las credenciales Password y entrega los tokens de acceso
y refresco. El usuario inicial es `CSPSystem/SYS`, con rol `%All`; sustituye
estas credenciales por usuarios nominales antes de un despliegue compartido.

## Tools nativas de AI Hub

Una tool se implementa con una clase que extiende `%AI.Tool`. AI Hub genera el
descriptor de cada método público mediante `%Discover()`; ese mismo descriptor
es el que se almacena y presenta en la consola.

El ejemplo `App.Demo.InventoryTools` publica `SearchInventory`, que consulta la
tabla persistente de `App.Demo.Inventory`, y `AddInventoryItem`, que registra un
nuevo producto indicando nombre, SKU o referencia única y cantidad inicial.

`Inventory.Name` dispone del índice full-text `NameSearchIndex`, definido como
`%iFind.Index.Basic` para español, minúsculas y stemming. El bootstrap construye
el índice después de sembrar los datos de demostración.

```objectscript
Class App.Demo.InventoryTools Extends %AI.Tool
{
Method SearchInventory(
    name As %String(DESCRIPTION = "Texto incluido en el nombre del producto")
) As %DynamicObject
{
    set startedAt = $zhorolog
    set resultSet = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Sku, Name, Stock FROM App_Demo.Inventory " _
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'es') " _
        "ORDER BY Name", name)
    quit ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 25, startedAt)
}
}
```

`AddInventoryItem(name, sku, quantity)` crea un producto cuando el nombre no
existe. Si encuentra una coincidencia exacta por nombre, suma `quantity` al
stock existente y conserva el SKU almacenado, aunque la llamada contenga otra
referencia. Para las altas nuevas rechaza referencias vacías o duplicadas; en
todos los casos rechaza nombres vacíos y cantidades negativas. Como cualquier
otra tool, debe asignarse explícitamente a los agentes que puedan utilizarla.

El dominio de demostración incluye además `App.Demo.Shipment` y
`App.Demo.ShipmentProduct`. El bootstrap crea ocho envíos y 23 líneas asociadas
a los productos del inventario. Cada envío conserva referencia, cliente, fecha
de envío, fecha de recepción e importe total; cada línea conserva producto,
cantidad e importe total del producto.

`App.Demo.ShipmentTools` publica:

- `SearchShipmentsByProduct(productId)`, que devuelve todos los envíos que
  contienen el ID de producto indicado;
- `SearchShipmentsByDateRange(startDate, endDate)`, que filtra inclusivamente
  por fecha de envío. Si `startDate` está vacío solo aplica `<= endDate`; si
  `endDate` está vacío solo aplica `>= startDate`; si ambos están vacíos devuelve
  todos los envíos. Las fechas usan el formato `YYYY-MM-DD`.

`POST /api/app/tools/sync` vuelve a inspeccionar las clases compiladas. Los
métodos nuevos se incorporan aprobados y habilitados; los que han desaparecido
se marcan `retired`. Los estados existentes y las asignaciones dinámicas no se
sobrescriben.

Como `AddTool()` registra una instancia completa, la factoría utiliza un
adaptador interno para exponer únicamente cada método asignado al agente. La
implementación y la ejecución siguen perteneciendo a la clase `%AI.Tool` real.

## Policies y agentes

| Tipo | Clase base requerida | Aplicación en el agente |
|---|---|---|
| `authorization` | `%AI.Policy.Authorization` | `SetAuthPolicy()` |
| `audit` | `%AI.Policy.Audit` | `SetAuditPolicy()` |
| `discovery` | `%AI.Policy.Discovery` | `SetDiscoveryPolicy()` |

Una vez registrados los metadatos en `App.Governance.Model` y la conexión en
Config Store, el agente se materializa por su nombre lógico:

```objectscript
set sc = ##class(App.AIHub.AgentFactory).Create("nombre-del-agente", .agent)
set session = agent.CreateSession()
set response = agent.Chat(session, "Busca productos cuyo nombre contenga café")
write response.Content
```

La factoría vuelve a resolver las tablas `AgentTool` y `ToolPolicy` al crear el
agente, por lo que IRIS conserva el control de la superficie disponible y de
las auditorías aplicables. `App.AIHub.Policy.DynamicAudit` compone las policies
asignadas a cada tool; el ejemplo `database-audit` persiste los eventos en
`App.Governance.AuditEvent`.

## Chat y autorización de usuarios

La pantalla **Chat de agentes** permite seleccionar cualquiera de los agentes
aprobados. La primera llamada crea una `%AI.Agent.Session`; las siguientes
reutilizan esa sesión para conservar el contexto. La conversación, su usuario
propietario y el transcript se guardan en IRIS.

`App.AIHub.Policy.UserAccess` extiende `%AI.Policy.Authorization`. IRIS valida
el Bearer JWT y establece el sujeto autenticado; la policy cruza ese sujeto con
`App.Governance.AIUser` y `App.Governance.AgentUser`. La comprobación se realiza
antes de invocar el modelo y de nuevo dentro del `ToolManager` para descubrir y
ejecutar tools. La conversación solo puede continuar con el mismo usuario y
agente con los que fue creada.

La pestaña **Usuarios IA** permite dar de alta, bloquear y reactivar usuarios,
y seleccionar dinámicamente qué agentes puede ejecutar cada uno. Solo se
admiten nombres que existan en el registro de seguridad de IRIS. El bootstrap
autoriza `CSPSystem`; sus agentes permitidos se seleccionan desde la propia
plataforma y se almacenan en IRIS.

## API

| Método | Ruta | Uso |
|---|---|---|
| `GET` | `/api/app/health` | Salud de la plataforma IRIS AI Hub |
| `POST` | `/api/app/login` | Obtener access y refresh JWT con credenciales IRIS |
| `POST` | `/api/app/refresh` | Renovar el par de tokens JWT |
| `POST` | `/api/app/logout` | Invalidar la sesión JWT |
| `GET/POST` | `/api/app/ai-users` | Allow-list de usuarios autorizados |
| `PUT` | `/api/app/ai-users/:username/agents` | Agentes permitidos para un usuario |
| `GET` | `/api/app/my-agents` | Agentes permitidos para el sujeto del JWT |
| `POST` | `/api/app/chat` | Enviar un mensaje y continuar una conversación |
| `GET` | `/api/app/providers` | Proveedores soportados |
| `GET/POST` | `/api/app/models` | Catálogo de modelos |
| `PUT` | `/api/app/models/:modelName` | Actualizar configuración y ciclo de vida de un modelo |
| `GET` | `/api/app/tools` | Métodos `%AI.Tool` descubiertos |
| `PUT` | `/api/app/tools/:toolName` | Actualizar gobierno, metadatos y auditorías de una tool |
| `POST` | `/api/app/tools/sync` | Sincronizar el catálogo del namespace |
| `GET/POST` | `/api/app/policies` | Policies registradas por tipo |
| `GET/POST` | `/api/app/agents` | Definiciones de agentes |
| `PUT` | `/api/app/agents/:agentName` | Actualizar modelo, parámetros, tools y policies de un agente |
| `GET/PUT` | `/api/app/agents/:agentName/tools` | Consultar o reemplazar la allow-list |
| `GET` | `/api/app/agents/:agentName/catalog` | Catálogo efectivo entregado al agente |
| `GET/PUT` | `/api/app/tools/:toolName/policies` | Auditorías asignadas a una tool |
| `GET` | `/api/app/audit-events` | Historial persistente de ejecuciones |
| `POST` | `/api/app/agents/:agentName/test` | Inferencia de prueba mediante el agente |

## Estructura

```text
iris/src/App/Governance/       # modelo persistente y validaciones
iris/src/App/REST/             # API administrativa
iris/src/App/Demo/             # modelo y %AI.Tool de ejemplo
iris/src/App/AIHub/            # policies, adaptador y factoría AI Hub
iris/src/App/Interop/          # producción, mensajes, service y operation
frontend/src/                  # consola React
  i18n.tsx                     # catálogos español/inglés y contexto de idioma
webgateway/shared/             # configuración del Gateway
```

Todo el código ObjectScript se carga desde `iris/src`. AI Hub es una
dependencia obligatoria de la solución.

## Desarrollo del frontend

```powershell
Set-Location frontend
npm install
npm run dev
```

Vite redirige `/api/app` a `http://localhost:8080`.

### Internacionalización del frontend

La consola React está disponible en español e inglés. Inicialmente adopta el
idioma del navegador y guarda la selección explícita en la clave
`ai-governance-language` de `localStorage`. El selector está disponible tanto
en la pantalla de login como en la cabecera autenticada; el cambio actualiza
toda la interfaz inmediatamente y establece el atributo `lang` del documento.

Las traducciones y la interpolación están centralizadas en
`frontend/src/i18n.tsx`. Los valores de dominio devueltos por IRIS —como los
nombres o descripciones de modelos, agentes, policies y tools— se muestran tal
como están almacenados y no son traducidos por el cliente.
