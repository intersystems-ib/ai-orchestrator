# AI Orchestrator

[English](README.md) | **Español**

Gobierna y compone agentes con el [SDK ObjectScript de InterSystems AI Hub](https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk), una consola React e interoperabilidad IRIS. Los ejemplos de negocio se ejecutan en servidores MCP separados.

## Separación de los ejemplos de negocio

El IRIS principal contiene AI Orchestrator, su catálogo, agentes, policies y
sesiones. Los datos y las herramientas de inventario y envíos viven en
`iris-demo/` (namespace `DEMO`) y se consumen mediante su servidor MCP.
`iris-mcp/` mantiene el ejemplo independiente de cotizaciones.

| Servicio | Responsabilidad | Endpoint MCP desde Orchestrator |
|---|---|---|
| `iris` | Orquestación y gobierno | Cliente MCP |
| `iris-demo` + `iris-demo-transport` | Inventario y envíos | `http://iris-demo-transport:8080/mcp` |
| `iris-mcp` + `iris-mcp-transport` | Cotizaciones por fecha | `http://iris-mcp-transport:8080/mcp` |

Los ejemplos usan nombres, descripciones y datos en inglés. Los índices iFind
usan `LANGUAGE="en"` en ambos servidores de ejemplos. La construcción del IRIS
principal no incluye clases `App.Demo` ni carga datos de negocio.

En la primera instalación, registra cada servidor de ejemplo en **Servidores MCP**,
descubre sus herramientas y asigna las permitidas a los agentes.

Ejemplos completos de configuración y registro MCP: [inventario y envíos](iris-demo/README_es.md#configurar-la-publicación-en-iris) y [cotizaciones](iris-mcp/README_es.md#configurar-la-publicación-en-iris). Incluyen las clases de servicio, el endpoint IRIS, `config.toml`, la consola y la API.

Antes de construir, copia `.env.example` a `.env` y configura `IRIS_IMAGE` con una imagen de IRIS que incluya AI Hub y a la que tengas acceso. `intersystems/iris-community:2027.1.0AI.109.0` es la etiqueta de la imagen EAP importada localmente. No se requiere un registro interno concreto. La preview validada es IRIS AI Hub `2027.1.0AI.109.0`, importada desde su imagen EAP. Las credenciales de ejemplo son solo de desarrollo y deben configurarse para cada despliegue.

## Delegación entre agentes

Al crear o editar un agente, **Agentes a los que puede delegar** permite seleccionar
otros agentes registrados, aprobados y habilitados. Las asignaciones aparecen
también en la lista de agentes. El backend las expone como `delegates` en la
declaración del agente, junto a `tools` y `policies`:

```json
{"delegates":["agente-logistica","agente-precios"]}
```

Cada asignación genera automáticamente una herramienta para el modelo del
coordinador. Esa herramienta admite un `prompt` e invoca al agente elegido con su
propio modelo, instrucciones, herramientas y policies, en una conversación nueva.
El usuario debe estar autorizado para ambos agentes. La delegación no concede
permisos nuevos ni comparte automáticamente el historial completo del coordinador.
La auditoría se aplica según las policies de cada agente y conserva el mismo
RequestId para relacionar las llamadas.

Se rechazan autorreferencias y ciclos. En ejecución se limitan la profundidad a
tres niveles, las llamadas delegadas a dieciséis por petición y cada espera a
120 segundos. El especialista se ejecuta en un job IRIS independiente; no requiere
BPL ni una producción activa.

Las pruebas con proveedor local están en `iris/tests/delegation/README_es.md`.

## Introducción y demostración con Slidev

El perfil Docker `demo` añade una presentación ejecutable con guion para el
ponente, explicación de agente, herramienta, modelo LLM y servidor MCP,
presentación de AI Hub y una consulta sencilla con AI Orchestrator:

```powershell
docker compose --profile demo up -d --build demo
```

Disponible en [http://localhost:3030](http://localhost:3030). No arranca los demás
servicios ni modifica el catálogo. Consulta [demo/README.md](demo/README_es.md) para
preparar los datos y el agente, o editar las slides con npm.
La consola admite enlaces directos a sus secciones, como `/#agents` y `/#mcp`.

## Capacidades

- Catálogo gobernado de modelos con configuración de proveedor integrada.
- Visualización y edición desde la consola de todos los datos de modelos,
  agentes y tools, incluidas sus asignaciones dinámicas.
- Descubrimiento de los métodos publicados por todas las clases de aplicación
  compiladas en el namespace que extienden `%AI.Tool`.
- Selección dinámica de los métodos disponibles para cada agente.
- Descubrimiento, búsqueda y ejecución gobernada de herramientas de servidores MCP externos.
- Chat multi-turno para probar cualquier agente aprobado, con sesiones y
  mensajes persistidos en IRIS.
- Enrutamiento de las inferencias de consola/API por una producción de
  interoperabilidad, conservando petición y respuesta en el Message Bank.
- Allow-list de usuarios IRIS y policy `%AI.Policy.Authorization` obligatoria
  tanto para iniciar chats como para descubrir o ejecutar tools.
- Registro de policies de autorización, auditoría y descubrimiento, validando
  el contrato nativo correspondiente de AI Hub.
- Asignaciones agente→tool y agente→policy almacenadas íntegramente en IRIS y
  modificables sin recompilar ObjectScript.
- Auditoría persistente de llamadas a tools, con agente, argumentos, resultado,
  duración y estado de ejecución.
- Factoría que materializa cada definición como `%AI.Agent`, registra solamente
  los métodos permitidos con `ToolManager.AddTool()` y configura sus policies.
- Ciclo de vida `draft`, `approved`, `suspended` y `retired`.

### Resumen funcional

| Área | Características |
|---|---|
| Modelos | Conexión, capacidad máxima de contexto, ciclo de vida y eliminación con control de dependencias |
| Agentes | Modelo, instrucciones, iteraciones, tools, delegados, policies, presupuesto de entrada y reserva de respuesta |
| Tools | Descubrimiento de herramientas locales y de servidores MCP, con asignación por agente |
| Policies | Autorización obligatoria, descubrimiento y auditorías configuradas exclusivamente en cada agente |
| Identidad | Autenticación JWT de IRIS, allow-list de usuarios y autorización usuario→agente |
| Chat | Pestañas Chat y Estadísticas de la conversación; mensajes persistidos, contexto e historial de resúmenes |
| Auditoría | Registro persistente de agente, tool, argumentos, resultado, duración y errores |
| Ejemplos | Servidores MCP separados: inventario/envíos en `iris-demo` y cotizaciones en `iris-mcp` |

Toda la configuración funcional se resuelve en IRIS. Docker Compose únicamente
define la infraestructura ejecutable —IRIS, Web Gateway, frontend y servidores
LLM locales—; no es la fuente de configuración de modelos, agentes, tools,
policies o autorizaciones.

```text
clases %AI.Tool ──> %Discover() ──> catálogo IRIS
                                           │
                              asignación agente→método
                                           │
                              asignación agente→audit policy
                                           │
modelo + configuración de agente ──────────┤
                                           ▼
API REST ──> Business Service ──> Business Operation ──> %AI.Agent
                │                       │                      │
                └──── mensajes IRIS ────┴──── tools/policies ─┘
```

## Producción de interoperabilidad

La consola utiliza `App.Interop.Production` como ruta obligatoria para las
llamadas a un LLM. La API crea un `App.Interop.Message.ChatRequest` y lo entrega de forma
síncrona al Business Service `AI Governance API Service`. Este reenvía el
mensaje al Business Operation `AI Hub LLM Operation`. La ejecución gobernada
se comparte con `App.Interop.AgentOperation`, que permite usar agentes desde BPL.

IRIS persiste las cabeceras y los cuerpos de petición y respuesta en el Message
Bank. Cada petición incorpora un `RequestId`, usuario JWT, agente, conversación,
propósito y fecha. La respuesta conserva estado, error, duración y resultado.
Ese mismo `RequestId` se propaga a los mensajes funcionales del chat y a las
auditorías de tools, permitiendo correlacionar los niveles HTTP,
interoperabilidad, agente y herramienta.

En las llamadas REST, la API transmite explícitamente el sujeto JWT validado.
Los jobs de producción utilizan esa identidad mediante el contexto local, en
lugar de sustituirla por su propia cuenta de servicio IRIS. La producción queda
configurada para arranque automático durante el bootstrap.

### Agentes como Business Operations de BPL

Añade una operación de clase `App.Interop.AgentOperation` a tu producción. Su
único ajuste específico es **AgentName**, un selector de los agentes aprobados
y habilitados almacenados en el namespace actual. Puedes crear varias
operaciones de esta clase, cada una con un agente distinto. Los ajustes estándar
de interoperabilidad, como la cola y los tiempos de espera, siguen disponibles.

La entrada es `Ens.StringRequest.StringValue`, que contiene el prompt, y la
salida `Ens.StringResponse.StringValue`, que contiene exclusivamente el texto
de la respuesta. Cada mensaje inicia una conversación independiente. Modelo,
instrucciones, herramientas y policies se toman de la definición del agente,
sin repetirlos en la producción.

En este caso, la identidad es el usuario IRIS del job de producción (`$username`,
habitualmente `_Ensemble`), porque el mensaje de texto no transporta un JWT.
Ese usuario debe estar habilitado en **Usuarios IA** y tener asignado el agente.
La operación no concede permisos automáticamente ni acepta una identidad o un
agente alternativo dentro del prompt.

Ejemplo de actividad BPL, con una operación configurada con el nombre
`Agente de operaciones`:

```xml
<call name="Consultar agente" target="Agente de operaciones" async="0" timeout="300">
  <request type="Ens.StringRequest">
    <assign property="callrequest.StringValue" value="request.StringValue" action="set" />
  </request>
  <response type="Ens.StringResponse">
    <assign property="response.StringValue" value="callresponse.StringValue" action="set" />
  </response>
</call>
```

En un BPL con otro contrato de entrada/salida, sustituye `request.StringValue`
y `response.StringValue` por las propiedades de tu mensaje o del contexto.
Los fallos de autorización, agente no disponible, prompt vacío o ejecución se
devuelven como `%Status` de error para que el BPL aplique su gestión de fallos.
La operación comprueba el estado del agente al arrancar y en cada petición.

Las llamadas conservan las policies, las conversaciones y la auditoría del
agente. La traza de interoperabilidad contiene los mensajes de texto originales.
El ejecutor compartido genera un `RequestId` para las conversaciones y auditorías.

La prueba en `iris/tests/bpl-agent/` utiliza un LLM simulado local y una producción
BPL de prueba. Debe ejecutarse únicamente en una instancia desechable: crea
usuarios, modelos y agentes de prueba y cambia la producción activa.

## Configuración segura de modelos

`App.Governance.Model` conserva exclusivamente los metadatos gobernados de cada
modelo:

- identidad y nombre visible;
- proveedor AI Hub;
- identificador comercial o alias local del modelo;
- estado de aprobación y activación;
- capacidad máxima de contexto declarada (`maxContextTokens`).

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
  "maxContextTokens": 4096,
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
  "maxContextTokens": 4096,
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
  "maxContextTokens": 16384,
  "apiKey": "not-needed",
  "status": "approved",
  "enabled": true
}
```

```json
{
  "name": "qwen3.5-9b",
  "provider": "nim",
  "modelId": "qwen3.5-9b",
  "baseUrl": "http://qwen:8000/v1",
  "maxContextTokens": 4096,
  "apiKey": "not-needed",
  "status": "approved",
  "enabled": true
}
```

El puerto es `8000` porque la comunicación se realiza entre contenedores. Los
puertos `8000` y `8001` publicados en el host se usan solamente para acceder a
Llama y Qwen respectivamente desde fuera de la red Docker.

Estos registros son datos del namespace y no forman parte de la imagen ni del
bootstrap. En una base de datos nueva deben registrarse de nuevo desde la
plataforma.

Las capacidades anteriores corresponden a `.env.example`. Si cambia el contexto
del servidor, ajusta `maxContextTokens` al valor real del endpoint; editar el
modelo no redimensiona el servidor. Las variables y archivos necesarios están en
[models/README_es.md](models/README_es.md).

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
intersystems/iris-community:2027.1.0AI.109.0
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

En el IRIS independiente `iris-demo`, el ejemplo `App.Demo.InventoryTools` publica `SearchInventory`, que consulta la
tabla persistente de `App.Demo.Inventory`, y `AddInventoryItem`, que registra un
nuevo producto indicando nombre, SKU o referencia única y cantidad inicial.

`Inventory.Name` dispone del índice full-text `NameSearchIndex`, definido como
`%iFind.Index.Basic` con `INDEXOPTION=1`, `LANGUAGE="en"` y `LOWER=1`. El bootstrap construye
el índice después de sembrar los datos de demostración.

```objectscript
Class App.Demo.InventoryTools Extends %AI.Tool
{
Method SearchInventory(
    name As %String(DESCRIPTION = "Words to match in the product name")
) As %DynamicObject
{
    set startedAt = $zhorolog
    set resultSet = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Sku, Name, Stock FROM App_Demo.Inventory " _
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'en') " _
        "ORDER BY Name", name)
    return ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 25, startedAt)
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
`App.Demo.ShipmentProduct`. El bootstrap de `iris-demo` crea ocho envíos y 23 líneas asociadas
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

`POST /api/app/tools/sync` inspecciona solo las clases compiladas en el núcleo.
Para las herramientas de `iris-demo` o `iris-mcp`, utiliza
`POST /api/app/mcp-servers/:serverName/tools/sync`. Los
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

Tras registrar el modelo, el agente y las autorizaciones del usuario, utiliza
el punto de entrada gobernado para aplicar conjuntamente las policies, la
persistencia de sesión y los presupuestos de contexto:

```objectscript
set sc = ##class(App.Interop.Gateway).Send("nombre-agente",
    "Busca productos cuyo nombre contenga Coffee", "", $username, "example", .result, .httpStatus)
if $SYSTEM.Status.IsOK(sc) write result.content
```

El usuario IRIS debe estar autorizado para ese agente y la producción debe estar
activa. Crear un `%AI.Agent` directamente es una operación de bajo nivel del SDK:
no aplica automáticamente la persistencia del chat ni la preparación del
presupuesto de contexto.

La factoría resuelve las herramientas y policies de cada agente desde IRIS.
`App.AIHub.Policy.DynamicAudit` compone las policies de auditoría aprobadas y
habilitadas seleccionadas en el agente y las aplica a todas sus ejecuciones de
tools. La policy `database-audit` persiste los eventos en
`App.Governance.AuditEvent`. Las tools no tienen configuración de auditoría propia.

## Chat y autorización de usuarios

La pantalla **Chat de agentes** permite seleccionar cualquiera de los agentes
aprobados. La primera llamada crea una `%AI.Agent.Session`; las siguientes
reutilizan esa sesión para conservar el contexto. La conversación, su usuario
propietario y el transcript se guardan en IRIS.

La vista tiene dos pestañas: **Chat** y **Estadísticas de la conversación**.
Al alternarlas se conservan el historial y el borrador. La segunda muestra el
identificador de conversación y las estadísticas nativas de
`%AI.Agent.Session.GetStats()`, actualizadas después de cada respuesta: interacciones,
tokens de entrada y salida, llamadas a herramientas, tiempo del LLM y uso del
contexto. El rendimiento sigue la fórmula del SDK: tokens de entrada más salida
divididos por el tiempo del LLM. Razonamiento, caché y tiempo de herramientas se
muestran cuando tienen actividad. Son acumulados de esa sesión, sin sumar las
sesiones de agentes delegados. Los campos no disponibles aparecen como «—» y un
fallo de telemetría no impide recibir una respuesta correcta del chat.
La conversación conserva además la exportación nativa `session.Export()` y la
restaura con `session.Import()` al continuar. Esto conserva explícitamente el contexto
y las estadísticas entre peticiones. Cada respuesta correcta guarda el estado
nativo de su conversación.

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

| Método | Ruta | Función |
|---|---|---|
| `GET` | `/api/app/health` | Salud de la plataforma |
| `POST` | `/api/app/login` | Obtener JWT de IRIS (gestor nativo) |
| `POST` | `/api/app/refresh` | Renovar JWT (gestor nativo) |
| `GET/POST` | `/api/app/ai-users` | Registro de usuarios IA |
| `PUT` | `/api/app/ai-users/:username/agents` | Asignaciones de agentes al usuario |
| `GET` | `/api/app/my-agents` | Agentes autorizados para el usuario |
| `POST` | `/api/app/chat` | Iniciar/continuar conversación; devolver estadísticas y resúmenes |
| `GET` | `/api/app/providers` | Campos de proveedores admitidos |
| `GET/POST` | `/api/app/models` | Listar/crear modelos y capacidades declaradas |
| `PUT/DELETE` | `/api/app/models/:modelName` | Actualizar/eliminar modelo; bloqueado si tiene agentes |
| `GET` | `/api/app/tools` | Catálogo de herramientas locales y MCP importadas |
| `POST` | `/api/app/tools/sync` | Descubrir herramientas locales compiladas en APP |
| `PUT` | `/api/app/tools/:toolName` | Actualizar gobierno de herramienta |
| `GET/POST` | `/api/app/policies` | Policies registradas |
| `GET/POST` | `/api/app/agents` | Listar/crear agentes |
| `PUT/DELETE` | `/api/app/agents/:agentName` | Actualizar/eliminar agente; comprobar dependencias |
| `GET/PUT` | `/api/app/agents/:agentName/tools` | Consultar/reemplazar herramientas asignadas |
| `GET` | `/api/app/agents/:agentName/catalog` | Catálogo efectivo del agente |
| `POST` | `/api/app/agents/:agentName/test` | Inferencia gobernada del agente |
| `GET/POST` | `/api/app/mcp-servers` | Listar/registrar servidores MCP |
| `PUT/DELETE` | `/api/app/mcp-servers/:serverName` | Actualizar/eliminar servidor; bloqueado si sus tools están asignadas |
| `GET` | `/api/app/mcp-servers/:serverName/tools` | Herramientas importadas de un servidor |
| `POST` | `/api/app/mcp-servers/:serverName/tools/sync` | Descubrir/actualizar catálogo MCP remoto |
| `GET` | `/api/app/audit-events` | Historial de auditoría de herramientas |

Las propiedades `tools`, `delegates`, `policies`, `contextBudget` y `responseReserve` se editan mediante POST/PUT del agente. Salir de la consola elimina los JWT guardados en ese navegador.

## Estructura

```text
iris/src/App/Governance/       # modelo persistente y validaciones
iris/src/App/REST/             # API administrativa
iris-demo/src/                # inventario/envíos y publicación MCP separados
iris-mcp/src/                 # cotizaciones y publicación MCP separadas
iris/config/                  # descriptor de modelos de Config Store en %SYS
iris/src/App/AIHub/            # policies, adaptador y factoría AI Hub
iris/src/App/Interop/          # producción, mensajes, service y operation
frontend/src/                  # consola React
  i18n.tsx                     # catálogos español/inglés y contexto de idioma
webgateway/shared/             # configuración del Gateway
```

Cada imagen IRIS carga su propio directorio de clases; el núcleo instala además
el descriptor de Config Store en `%SYS`. AI Hub es una dependencia obligatoria.

## Servidores MCP externos

El despliegue incluye `iris-demo` para inventario/envíos y un IRIS independiente
llamado `iris-mcp` para cotizaciones, construido con
la misma imagen que el backend y con datos persistentes propios. Publica un
servicio nativo `%AI.MCP.Service` con `SearchInventory` y `GetDailyPrices`.
La única clase persistente de la demostración externa es `External.Demo.Price`,
con nombre de producto, fecha, precio y moneda, sin relaciones. Las consultas
usan el mismo índice iFind que `App.Demo.Inventory`. Los precios son ficticios en EUR.
El contenedor
`iris-mcp-transport` utiliza el binario oficial `iris-mcp-server` para exponerlo
por HTTP MCP en `http://localhost:8082/mcp` (solo en el equipo local).

La consola dispone de la pestaña **Servidores MCP** para registrar y editar
endpoints externos, su autenticación y sus estados de gobierno. Desde el
backend, el endpoint de pruebas es `http://iris-mcp-transport:8080/mcp`. Los
tokens se indican mediante referencias `secret://...` de Secure Wallet.

En cada servidor aprobado y habilitado, el icono de actualización
(**Descubrir herramientas**) consulta el
catálogo MCP completo, incluida su paginación. El icono de lista
(**Ver herramientas**) abre un modal amplio con búsqueda por nombre o descripción
y consulta de parámetros. Las herramientas
se incorporan al catálogo de tools con su servidor de origen y se pueden
seleccionar al editar cualquier agente. Solo se exponen los métodos asignados
a ese agente y se aplican sus policies de autorización y auditoría.

La sincronización conserva nombres locales, asignaciones y estados de gobierno.
Las herramientas nuevas quedan aprobadas y habilitadas, igual que en el catálogo
local. Las que desaparecen del servidor se marcan no disponibles. Si falla la
consulta, se conserva el catálogo anterior. Deshabilitar o suspender un servidor
impide utilizar sus tools; cambiar su URL o autenticación exige redescubrirlas.

La API ofrece `GET/POST /api/app/mcp-servers` y
`PUT /api/app/mcp-servers/:serverName`, además de
`POST /api/app/mcp-servers/:serverName/tools/sync` para descubrir y
`GET /api/app/mcp-servers/:serverName/tools` para consultar las tools importadas.
Los servidores se persisten en `App.Governance.MCPServer` y las herramientas en
`App.Governance.Tool`, distinguiendo el origen local o MCP. El cliente usa
Streamable HTTP, respuestas JSON o SSE y sesiones MCP breves. Las conexiones
HTTPS verifican el certificado con la configuración TLS `APP.MCP.Client`.

Consulta [iris-mcp/README.md](iris-mcp/README_es.md) para la configuración y los
puertos de la instancia externa.

## Desarrollo del frontend

```powershell
Set-Location frontend
npm ci
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

## Requisito de imagen

La imagen predeterminada es `intersystems/iris-community:2027.1.0AI.109.0`. Importa
la imagen EAP de AI Hub con `docker load -i <archivo>` y configura su etiqueta en
`IRIS_IMAGE`, o asígnale localmente la etiqueta predeterminada del proyecto.
Las tres construcciones IRIS y ambos transportes usan la misma imagen. Debe
incluir el SDK de AI Hub e `iris-mcp-server`; las etiquetas preview variables
pueden contener componentes distintos.

La construcción inicial del núcleo instala `App.AIHub.Config.ModelDescriptor`
en `%SYS`, registra el esquema de Config Store y compila todas las clases.
Cada imagen de ejemplos prepara y siembra únicamente su namespace. Consulta
[Arranque](#arranque).

## Presupuestos de contexto por agente

Los modelos declaran `maxContextTokens`, la capacidad total real del endpoint
LLM. Es un dato de validación y no reconfigura el servidor remoto. Para Llama
local debe coincidir con `LLM_CONTEXT_SIZE` en Compose; cambiar esa variable
requiere recrear Llama. Los modelos nuevos usan 4096 tokens si se omite el campo; declara el valor real
de cada endpoint.

Los agentes declaran `contextBudget` (entrada) y `responseReserve` (máximo de
tokens generados **por llamada al modelo**). La entrada incluye instrucciones,
definiciones de herramientas y agentes delegados, historial, resultados de
herramientas y el mensaje nuevo. `contextBudget + responseReserve` no puede
superar la capacidad del modelo. Con presupuesto 0 se hereda
`maxContextTokens - responseReserve`; la reserva predeterminada es 1024.
Por ejemplo, un endpoint de 16384 tokens puede servir un agente con presupuesto
de entrada 12000 y reserva 2048. Se rechaza reducir la capacidad del modelo si
alguno de sus agentes dejaría de caber.

Antes de cada mensaje, el Orchestrator comprueba la entrada con una cota
de un token por cada tres bytes UTF-8 y margen de formato, sin asumir el
tokenizador exacto del proveedor. La tokenización real puede diferir: no es una
garantía estricta de tokens y puede resumir de forma anticipada. El mecanismo
principal es `session.Summarize(provider, model, 1, prompt)`: el SDK genera una
memoria estructurada y conserva explícitamente el último mensaje. En la preview
build 109, pasar 0 selecciona los diez mensajes recientes predeterminados.
El resumen sustituye solo el contexto de la sesión nativa.
El transcript completo y las estadísticas acumuladas de la sesión se conservan.
Los resúmenes generan llamadas adicionales al modelo, cuyo consumo no se incluye
en las estadísticas nativas de la sesión de chat. Si las instrucciones,
herramientas o mensaje nuevo no caben, o falla el resumen, se devuelve un error
sin truncar silenciosamente ni sustituir el estado persistido de la conversación.

El resumen por bloques queda únicamente como alternativa. Una prueba real con
Llama y una capacidad de 16384 tokens confirmó que `Summarize()` envía un
historial demasiado grande en una sola petición: una entrada de aproximadamente
20000 tokens fue rechazada con `exceed_context_size_error`. Solo se utilizan
bloques ante ese código explícito o si el resumen del SDK aún supera el presupuesto
(por ejemplo, porque conserva un último mensaje demasiado grande). Antes de pasar
a bloques se restaura el estado original; si el último mensaje completo del
asistente es pequeño y cabe, se conserva literalmente. Los demás errores del SDK o proveedor
se devuelven sin ese reintento. La respuesta indica el mecanismo utilizado en
`contextManagement.summaryMethod`: `none`, `sdk` o `blocks`.

La comprobación se realiza al inicio de cada turno. Los resultados de herramientas
generados durante ese turno utilizan la salvaguarda nativa
`auto_compact_on_token_limit`; el presupuesto de entrada no se aplica como contador
estricto entre iteraciones internas del SDK. No garantiza que quepa un resultado
individual de herramienta demasiado grande. Limita las salidas de herramientas y
declara la capacidad real del endpoint. El panel de estadísticas del chat muestra
la capacidad declarada, el presupuesto de entrada, la reserva y si se resumió el
historial antes del último mensaje.

Consulta las [pruebas de contexto](iris/tests/context-budget/README_es.md) para la validación aislada.

## Eliminación de registros e historial de resúmenes

Las estadísticas del chat conservan la fecha del último resumen (hora del
servidor), el método (Summarize del SDK o bloques) y el contador al continuar la
conversación. Antes del primer resumen no se muestra una fecha de resumen. La indicación del último envío se muestra por separado.

Los modelos, agentes y registros MCP incluyen una acción Eliminar con
un modal de confirmación con tipo, nombre visible e identificador del registro.
Las acciones de edición/eliminación usan iconos de lápiz/papelera con ayuda.
La API ofrece `DELETE /api/app/models/:nombre`, `DELETE /api/app/agents/:nombre`
y `DELETE /api/app/mcp-servers/:nombre`. Un modelo no se puede borrar mientras tenga
agentes configurados, cualquiera que sea su estado. Un servidor MCP no se puede
borrar si alguna de sus herramientas está definida en un agente. La API aplica
las mismas comprobaciones y devuelve HTTP 409 con la dependencia; si el registro
no existe, devuelve 404.

Eliminar un registro MCP sin dependencias retira sus herramientas descubiertas
del catálogo y mantiene el servidor remoto funcionando. Un agente no se puede
eliminar si otro lo tiene asignado como delegado o hay una producción con un
ajuste AgentName que lo utiliza; en otro caso se retiran sus asignaciones de
herramientas, delegados y usuarios. Se conservan las conversaciones y la auditoría.
Eliminar un modelo sin agentes retira su configuración de conexión; el servidor
LLM y sus archivos permanecen.

## Diagnóstico del descubrimiento MCP

Los transportes MCP esperan a que el superservidor de IRIS acepte conexiones antes
de iniciar el cliente nativo. En la preview build 109, arrancar sin conexión y
reconectar puede dejar el descubrimiento nativo devolviendo HTTP 401. Si el
catálogo solo devuelve `iris_status` con un esquema vacío, revisa los registros
y la autenticación del transporte y reinícialo cuando IRIS esté preparado:

```powershell
docker compose restart iris-demo-transport iris-mcp-transport
```

El Orchestrator rechaza ese descriptor de diagnóstico inválido sin sustituir el
catálogo existente. Las acciones Ver herramientas y Descubrir herramientas usan
iconos de lista y actualización, con ayuda contextual y nombres accesibles.

## Validación de primera instalación

Este repositorio está orientado a instalaciones nuevas. Los directorios duraderos (`iris/shared`, `iris-demo/shared` e `iris-mcp/shared`) deben estar vacíos al comenzar. La construcción inicial crea los esquemas, la configuración nativa y los datos iniciales; no convierte despliegues existentes.

Antes de cargar los datos de pruebas, comprueba una instancia desechable del núcleo sin volúmenes persistentes:

```powershell
docker run -d --name ai-orchestrator-first-install-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Esperar al mensaje de arranque completo de IRIS.
Get-Content -Raw iris/tests/first-install.script | docker exec -i ai-orchestrator-first-install-test iris session IRIS
docker rm -f ai-orchestrator-first-install-test
```

Resultado esperado: `FIRST_INSTALL_FAILURES=0`. Comprueba los catálogos de aplicación vacíos, las policies y el administrador iniciales, la separación de los ejemplos de negocio y la inicialización repetible del bootstrap.
