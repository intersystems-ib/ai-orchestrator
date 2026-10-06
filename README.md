# AI Governance Hub

**English** | [Español](README_es.md)

An MVP for governing and composing agents on top of the
[InterSystems AI Hub ObjectScript SDK](https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk).
The Docker architecture includes IRIS, Web Gateway, a React console served by
Nginx, and two optional local llama.cpp servers.

## Capabilities

- Governed model catalog with integrated provider configuration.
- Full model, agent, and tool data can be viewed and edited from the console,
  including dynamic assignments.
- Discovery of published methods from every compiled application class in the
  namespace that extends `%AI.Tool`.
- Dynamic selection of the methods available to each agent.
- Multi-turn chat for testing any approved agent, with sessions and messages
  persisted in IRIS.
- Mandatory routing of every inference through an interoperability production,
  retaining its request and response in the Message Bank.
- IRIS user allow-list and mandatory `%AI.Policy.Authorization` policy for
  starting chats and discovering or executing tools.
- Authorization, audit, and discovery policy registration with validation
  against the corresponding native AI Hub contracts.
- Agent-to-tool and tool-to-policy assignments stored entirely in IRIS and
  editable without recompiling ObjectScript.
- Persistent tool-call audit trail including agent, arguments, result,
  duration, and execution status.
- A factory that materializes each definition as a `%AI.Agent`, registers only
  allowed methods through `ToolManager.AddTool()`, and applies its policies.
- `draft`, `approved`, `suspended`, and `retired` lifecycle states.

### Functional overview

| Area | Features |
|---|---|
| Models | Commercial and local model catalog, secure connection settings, approval, and activation |
| Agents | Model selection, system prompt, temperature, maximum iterations, tools, and policies |
| Tools | Discovery of methods published by `%AI.Tool` classes and per-agent assignment |
| Policies | Mandatory authorization, discovery rules, and audit policies dynamically applicable to each tool |
| Identity | IRIS JWT authentication, user allow-list, and user-to-agent authorization |
| Chat | Persistent conversations and messages, agent selection, and real AI Hub invocation |
| Audit | Persistent agent, tool, argument, result, duration, correlation ID, and error records |
| Demo | Persistent inventory, shipments, and product lines; iFind search, cumulative stock entry, and queries through four tools |

All functional configuration is resolved inside IRIS. Docker Compose only
defines executable infrastructure—IRIS, Web Gateway, the frontend, and local
LLM servers. It is not the source of truth for models, agents, tools, policies,
or authorizations.

```text
%AI.Tool classes ──> %Discover() ──> IRIS catalog
                                           │
                                  agent-to-method assignment
                                           │
                                  tool-to-audit-policy assignment
                                           │
model + agent configuration ───────────────┤
                                           ▼
REST API ──> Business Service ──> Business Operation ──> %AI.Agent
                │                       │                      │
                └──── IRIS messages ────┴──── tools/policies ─┘
```

## Interoperability production

`App.Interop.Production` is the mandatory path for every LLM call. The API
creates an `App.Interop.Message.ChatRequest` and synchronously submits it to the
`AI Governance API Service` Business Service. The service forwards the message
to the `AI Hub LLM Operation` Business Operation, the only component allowed to
materialize and execute an AI Hub agent.

IRIS persists request and response headers and bodies in the Message Bank. Each
request includes a `RequestId`, JWT user, agent, conversation, purpose, and
timestamp. The response retains status, error, duration, and result. The same
`RequestId` is propagated to functional chat messages and tool audit events,
which correlates the HTTP, interoperability, agent, and tool layers.

Identity is not obtained from `$username` inside the operation. The JWT subject
validated by the API travels explicitly in the message and is installed in the
job-local context before policies are evaluated. The production is configured
for automatic startup during bootstrap.

## Secure model configuration

`App.Governance.Model` stores only governed model metadata:

- logical identity and display name;
- AI Hub provider;
- commercial model identifier or local alias;
- approval and activation state.

Connection fields such as `apiKey`, `baseUrl`, and `region` are stored in
`%ConfigStore.Configuration`, not as properties or columns of
`App.Governance.Model`. Every record uses an internal, stable FQN in the form
`APP.AI.MODEL.model-<id>`. This relationship is derived from the immutable model
ID, so there is no `ConfigName` field or separate configuration for users to
manage.

The API and form continue to expose the same typed fields. `Create`, `Update`,
and `ListJSON` on `App.Governance.Model` transparently write and read Config
Store. Agents only add their behavior—prompt, temperature, iterations, tools,
and policies—to the selected governed model.

Secret material remains in Secure Wallet. Config Store contains
`secret://...` references, never plaintext API keys or tokens. When an agent is
materialized, IRIS requests the connection details from Config Store with
secret resolution enabled.

The current catalog supports these providers and fields:

| Provider ID | Provider | Supported connection fields |
|---|---|---|
| `openai` | OpenAI | `apiKey`, `baseUrl`, `orgId` |
| `anthropic` | Anthropic | `apiKey`, `baseUrl`, `version` |
| `gemini` | Google Gemini | `apiKey` |
| `bedrock` | AWS Bedrock | `region`, `bearerToken` |
| `vertex` | Google Vertex | `projectId`, `region`, `serviceAccountPath` |
| `meta` | Meta Llama | `apiKey` |
| `nim` | NVIDIA NIM and local OpenAI-compatible endpoints | `baseUrl`, `apiKey` |
| `xai` | xAI | `apiKey` |
| `deepseek` | DeepSeek | `apiKey`, `baseUrl` |
| `kimi` | Kimi / Moonshot AI | `apiKey`, `baseUrl` |
| `openrouter` | OpenRouter | `apiKey`, `siteUrl`, `siteName`, `baseUrl` |
| `ollama` | Ollama | `baseUrl` |

This table reflects the fields known by the catalog in this version. Exact
required fields, URLs, and credential mechanisms depend on the provider and
must be checked against the installed AI Hub SDK version.

### OpenAI example

Register the model from the console or with `POST /api/app/models`:

```json
{
  "name": "openai-production",
  "displayName": "OpenAI production",
  "provider": "openai",
  "modelId": "model-enabled-for-the-account",
  "apiKey": "secret://openai-production-api-key",
  "baseUrl": "https://api.openai.com/v1",
  "orgId": "optional-organization",
  "status": "approved",
  "enabled": true
}
```

### Anthropic example

```json
{
  "name": "anthropic-production",
  "displayName": "Anthropic production",
  "provider": "anthropic",
  "modelId": "model-enabled-for-the-account",
  "apiKey": "secret://anthropic-production-api-key",
  "baseUrl": "https://api.anthropic.com",
  "version": "provider-supported-version",
  "status": "approved",
  "enabled": true
}
```

### Included local models

The two llama.cpp servers in the `ai` profile expose an OpenAI-compatible API
inside the Docker network. Register each model with its own configuration:

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

Port `8000` is used for container-to-container communication. Host ports `8000`
and `8001` expose Llama and Qwen respectively outside the Docker network.

These records are namespace data and are not embedded in the image or
bootstrap. They must be registered again from the platform in a new database.

### Runtime resolution

When creating a session, `App.AIHub.AgentFactory`:

1. loads the approved agent from `App_Governance.Agent`;
2. resolves its approved model in `App_Governance.Model`;
3. obtains connection details associated with the model ID from
   `%ConfigStore.Configuration`;
4. asks Config Store to resolve `secret://` references;
5. creates the requested `%AI.Provider` and runs `ValidateConfig()`;
6. configures the `%AI.Agent` and attaches only authorized tools and policies.

The platform rejects direct values in `ApiKey` and `BearerToken`; they must be
`secret://` references, except for the explicit `not-needed` value used by local
models. If a secret cannot be resolved or `ValidateConfig()` fails, the agent
is not materialized and the call is rejected before chat begins.

## Startup

The solution requires the InterSystems IRIS image with AI Hub configured in
`docker-compose.yml`:

```text
docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.2.0AI.162.0
```

```powershell
Copy-Item .env.example .env
docker compose up --build
```

To also start both local models:

```powershell
docker compose --profile ai up -d --build
```

Bootstrap synchronizes the `%AI.Tool` catalog and prepares the platform's
technical resources. Models, provider configuration, agents, and assignments
are managed as persistent IRIS data; ObjectScript classes do not contain
hard-coded functional configuration values.

The `ai` profile starts both OpenAI-compatible servers:

- Llama at <http://localhost:8000>.
- Qwen 3.5 9B at <http://localhost:8001>, loading
  `models/Qwen3.5-9B-Q5_K_M.gguf` with alias `qwen3.5-9b`.

- UI: <http://localhost:5173>
- API: <http://localhost:8080/api/app/health>
- IRIS Management Portal: <http://localhost:52773/csp/sys/UtilHome.csp>

The development configuration uses the native IRIS JWT endpoint. `POST
/api/app/login` validates Password credentials and returns access and refresh
tokens. The initial user is `CSPSystem/SYS` with the `%All` role; replace these
credentials with named users before a shared deployment.

## Native AI Hub tools

A tool is implemented by a class extending `%AI.Tool`. AI Hub generates a
descriptor for every public method through `%Discover()`; the same descriptor
is stored and displayed in the console.

`App.Demo.InventoryTools` publishes `SearchInventory`, which queries the
persistent `App.Demo.Inventory` table, and `AddInventoryItem`, which registers
a product from its name, unique SKU or reference, and initial quantity.

`Inventory.Name` has a full-text `NameSearchIndex` defined as an
`%iFind.Index.Basic` index with Spanish language processing, lowercase
normalization, and stemming. Bootstrap builds it after seeding demo data.

```objectscript
Class App.Demo.InventoryTools Extends %AI.Tool
{
Method SearchInventory(
    name As %String(DESCRIPTION = "Text contained in the product name")
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

`AddInventoryItem(name, sku, quantity)` creates a product when its name does
not exist. On an exact name match, it adds `quantity` to the current stock and
keeps the stored SKU even if the call contains a different reference. New
records reject empty or duplicate references; all calls reject empty names and
negative quantities. Like every other tool, it must be explicitly assigned to
the agents allowed to use it.

The demo domain also includes `App.Demo.Shipment` and
`App.Demo.ShipmentProduct`. Bootstrap creates eight shipments and 23 product
lines linked to inventory items. A shipment stores reference, customer,
shipping date, receipt date, and total amount; each line stores the product,
shipped quantity, and product total.

`App.Demo.ShipmentTools` publishes:

- `SearchShipmentsByProduct(productId)`, returning every shipment containing
  the requested inventory product ID;
- `SearchShipmentsByDateRange(startDate, endDate)`, filtering inclusively by
  shipping date. An empty `startDate` only applies `<= endDate`; an empty
  `endDate` only applies `>= startDate`; when both are empty all shipments are
  returned. Dates use `YYYY-MM-DD`.

`POST /api/app/tools/sync` inspects compiled classes again. New methods are
added as approved and enabled, while removed methods are marked `retired`.
Existing lifecycle states and dynamic assignments are preserved.

Because `AddTool()` registers a complete instance, the factory uses an internal
adapter to expose only the method assigned to an agent. Implementation and
execution still belong to the real `%AI.Tool` class.

## Policies and agents

| Type | Required base class | Application to the agent |
|---|---|---|
| `authorization` | `%AI.Policy.Authorization` | `SetAuthPolicy()` |
| `audit` | `%AI.Policy.Audit` | `SetAuditPolicy()` |
| `discovery` | `%AI.Policy.Discovery` | `SetDiscoveryPolicy()` |

After metadata is registered in `App.Governance.Model` and connection details
in Config Store, materialize the agent by logical name:

```objectscript
set sc = ##class(App.AIHub.AgentFactory).Create("agent-name", .agent)
set session = agent.CreateSession()
set response = agent.Chat(session, "Find products whose name contains coffee")
write response.Content
```

The factory resolves `AgentTool` and `ToolPolicy` tables every time it creates
an agent, keeping control of the available surface and applicable audits inside
IRIS. `App.AIHub.Policy.DynamicAudit` composes policies assigned to each tool;
the `database-audit` example persists events in
`App.Governance.AuditEvent`.

## Chat and user authorization

The **Agent chat** screen can invoke any approved agent. The first call creates
a `%AI.Agent.Session`; subsequent calls reuse it to preserve context. IRIS
stores the conversation, its owning user, and its transcript.

`App.AIHub.Policy.UserAccess` extends `%AI.Policy.Authorization`. IRIS validates
the Bearer JWT and establishes the authenticated subject; the policy checks it
against `App.Governance.AIUser` and `App.Governance.AgentUser`. Authorization is
evaluated before model invocation and again inside `ToolManager` when tools are
discovered or executed. A conversation can only continue with its original
user and agent.

The **AI users** tab can register, block, and reactivate users and dynamically
choose which agents each user may execute. Names must exist in the IRIS security
registry. Bootstrap authorizes `CSPSystem`; its allowed agents are selected in
the platform and stored in IRIS.

## API

| Method | Route | Purpose |
|---|---|---|
| `GET` | `/api/app/health` | IRIS AI Hub platform health |
| `POST` | `/api/app/login` | Obtain access and refresh JWTs from IRIS credentials |
| `POST` | `/api/app/refresh` | Refresh the token pair |
| `POST` | `/api/app/logout` | Invalidate the JWT session |
| `GET/POST` | `/api/app/ai-users` | Authorized user allow-list |
| `PUT` | `/api/app/ai-users/:username/agents` | Agents allowed for a user |
| `GET` | `/api/app/my-agents` | Agents allowed for the JWT subject |
| `POST` | `/api/app/chat` | Send a message and continue a conversation |
| `GET` | `/api/app/providers` | Supported providers |
| `GET/POST` | `/api/app/models` | Model catalog |
| `PUT` | `/api/app/models/:modelName` | Update model configuration and lifecycle |
| `GET` | `/api/app/tools` | Discovered `%AI.Tool` methods |
| `PUT` | `/api/app/tools/:toolName` | Update tool governance, metadata, and audits |
| `POST` | `/api/app/tools/sync` | Synchronize the namespace catalog |
| `GET/POST` | `/api/app/policies` | Registered policies by type |
| `GET/POST` | `/api/app/agents` | Agent definitions |
| `PUT` | `/api/app/agents/:agentName` | Update an agent's model, parameters, tools, and policies |
| `GET/PUT` | `/api/app/agents/:agentName/tools` | Read or replace the tool allow-list |
| `GET` | `/api/app/agents/:agentName/catalog` | Effective catalog exposed to an agent |
| `GET/PUT` | `/api/app/tools/:toolName/policies` | Audits assigned to a tool |
| `GET` | `/api/app/audit-events` | Persistent execution history |
| `POST` | `/api/app/agents/:agentName/test` | Test inference through an agent |

## Project structure

```text
iris/src/App/Governance/       # persistent governance model and validation
iris/src/App/REST/             # administrative API
iris/src/App/Demo/             # sample domain model and %AI.Tool classes
iris/src/App/AIHub/            # policies, adapter, and AI Hub factory
iris/src/App/Interop/          # production, messages, service, and operation
frontend/src/                  # React console
  i18n.tsx                     # Spanish/English catalogs and language context
webgateway/shared/             # Web Gateway configuration
```

All ObjectScript source is loaded from `iris/src`. AI Hub is a mandatory
dependency.

## Frontend development

```powershell
Set-Location frontend
npm install
npm run dev
```

Vite proxies `/api/app` to `http://localhost:8080`.

### Frontend internationalization

The React console is available in English and Spanish. It initially follows
the browser language and stores the explicit selection under
`ai-governance-language` in `localStorage`. The selector is available both on
the login screen and in the authenticated header; changing it updates the
whole interface immediately and sets the document's `lang` attribute.

Translations and interpolation are centralized in `frontend/src/i18n.tsx`.
Domain values returned by IRIS—such as model, agent, policy, and tool names or
descriptions—are deliberately presented as stored and are not translated by
the client.
