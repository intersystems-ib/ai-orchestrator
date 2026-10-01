# AI Governance Hub

MVP de gobierno y composición de agentes sobre el
[ObjectScript SDK de InterSystems AI Hub](https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk).
La arquitectura Docker incluye IRIS, Web Gateway, una consola React servida
por Nginx y un servidor local llama.cpp opcional.

## Capacidades

- Catálogo gobernado de modelos y referencias a Config Store.
- Descubrimiento de los métodos publicados por todas las clases de aplicación
  compiladas en el namespace que extienden `%AI.Tool`.
- Selección dinámica de los métodos disponibles para cada agente.
- Chat multi-turno para probar cualquier agente aprobado, con sesiones y
  mensajes persistidos en IRIS.
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

```text
clases %AI.Tool ──> %Discover() ──> catálogo IRIS
                                           │
                              asignación agente→método
                                           │
                              asignación tool→audit policy
                                           │
modelo + configuración de agente ──────────┤
                                           ▼
                               %AI.Agent + %AI.ToolManager
```

El catálogo no almacena claves. `ConfigName` apunta a una configuración de AI
Hub, por ejemplo `AI.LLM.OpenAI.Production`, y sus secretos deben residir en
Secure Wallet usando referencias `secret://...`.

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

Para iniciar también el modelo Llama local:

```powershell
docker compose --profile ai up -d --build
```

El bootstrap sincroniza el catálogo de `%AI.Tool` y prepara los recursos
técnicos de la plataforma. Los modelos, sus referencias de Config Store, los
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
tabla persistente de `App.Demo.Inventory`:

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

Una vez configurado el Config Store del modelo, el agente se materializa por
su nombre lógico:

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
| `GET` | `/api/app/tools` | Métodos `%AI.Tool` descubiertos |
| `POST` | `/api/app/tools/sync` | Sincronizar el catálogo del namespace |
| `GET/POST` | `/api/app/policies` | Policies registradas por tipo |
| `GET/POST` | `/api/app/agents` | Definiciones de agentes |
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
frontend/src/                  # consola React
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
