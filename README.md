# AI Orchestrator

**English** | [Español](README_es.md)

Govern and compose agents with the [InterSystems AI Hub ObjectScript SDK](https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk), a React console and IRIS interoperability. Business examples run on separate MCP servers.

## Isolated business examples

The main IRIS owns AI Orchestrator, its catalog, agents, policies and sessions.
Inventory and shipment data and tools live in `iris-demo/` (namespace `DEMO`),
consumed through MCP. `iris-mcp/` remains the independent daily pricing example.

| Service | Responsibility | MCP endpoint from Orchestrator |
|---|---|---|
| `iris` | Orchestration and governance | MCP client |
| `iris-demo` + `iris-demo-transport` | Inventory and shipments | `http://iris-demo-transport:8080/mcp` |
| `iris-mcp` + `iris-mcp-transport` | Daily prices | `http://iris-mcp-transport:8080/mcp` |

Example data, comments and tool descriptions use English. Both example servers
use English iFind processing. The core image contains no `App.Demo` classes and
seeds no business data.

For the first installation, register each example server in **MCP servers**,
discover its tools and assign the permitted tools to agents.

Complete MCP configuration and registration examples: [inventory and shipments](iris-demo/README.md#configuring-publication-in-iris) and [daily prices](iris-mcp/README.md#configuring-publication-in-iris). They cover service classes, IRIS endpoints, `config.toml`, console registration and API requests.

Before building, copy `.env.example` to `.env` and set `IRIS_IMAGE` to an accessible IRIS image that includes AI Hub. `intersystems/iris-community:2027.1.0AI.109.0` is the tag of the EAP image imported locally. No specific internal registry is required. The validated preview is IRIS AI Hub `2027.1.0AI.109.0`, loaded from its EAP image. Sample credentials are for development and must be configured for each deployment.

## Agent delegation

When creating or editing an agent, select its **Agents available for delegation**
alongside its tools and policies. The `delegates` array in an agent definition
contains the logical names of approved, enabled registered agents:

```json
{"delegates":["logistics-agent","pricing-agent"]}
```

Each assignment creates a runtime tool accepting a `prompt`. The specialist uses
its own model, instructions, tools, policies and independent conversation. The
current user must be authorized for both agents. Each agent's configured audit
policies apply, with the same RequestId correlating their calls. Delegation does
not grant access or automatically share the caller's conversation.

Self references and cycles are rejected. Runtime limits are three delegation
levels, sixteen delegated calls per request and a 120-second wait per invocation.
Specialists execute in independent IRIS jobs without requiring BPL or an active
interoperability production.

See `iris/tests/delegation/README.md` for the isolated integration test with a local
mock provider.

## Introductory Slidev presentation and demonstration

The optional Docker `demo` profile adds a Spanish presentation with speaker
notes, definitions of agents, tools, LLMs and MCP servers, an introduction to
AI Hub and a simple AI Orchestrator query:

```powershell
docker compose --profile demo up -d --build demo
```

Open [http://localhost:3030](http://localhost:3030). This service does not start the
backend or modify its catalog. See [demo/README.md](demo/README.md) for preparation,
the agent setup and local editing. The frontend supports section links
such as `/#agents` and `/#mcp`.

## Capabilities

- Governed model catalog with integrated provider configuration.
- Full model, agent, and tool data can be viewed and edited from the console,
  including dynamic assignments.
- Discovery of published methods from every compiled application class in the
  namespace that extends `%AI.Tool`.
- Dynamic selection of the methods available to each agent.
- Discovery, search and governed execution of tools from external MCP servers.
- Multi-turn chat for testing any approved agent, with sessions and messages
  persisted in IRIS.
- Routing of console/API inference through an interoperability production,
  retaining its request and response in the Message Bank.
- IRIS user allow-list and mandatory `%AI.Policy.Authorization` policy for
  starting chats and discovering or executing tools.
- Authorization, audit, and discovery policy registration with validation
  against the corresponding native AI Hub contracts.
- Agent-to-tool and agent-to-policy assignments stored entirely in IRIS and
  editable without recompiling ObjectScript.
- Persistent tool-call audit trail including agent, arguments, result,
  duration, and execution status.
- A factory that materializes each definition as a `%AI.Agent`, registers only
  allowed methods through `ToolManager.AddTool()`, and applies its policies.
- `draft`, `approved`, `suspended`, and `retired` lifecycle states.

### Functional overview

| Area | Features |
|---|---|
| Models | Provider connection, maximum context capacity, lifecycle and dependency-aware deletion |
| Agents | Model, instructions, iterations, tools, delegated agents, policies, input budget and response reserve |
| Tools | Discovery of local and external MCP tools with per-agent assignment |
| Policies | Mandatory authorization, discovery rules, and audit policies configured exclusively on each agent |
| Identity | IRIS JWT authentication, user allow-list, and user-to-agent authorization |
| Chat | Separate Chat and Conversation statistics tabs; persistent messages, context usage and summary history |
| Audit | Persistent agent, tool, argument, result, duration, correlation ID, and error records |
| Examples | Separate MCP servers: inventory/shipments in `iris-demo`; daily quotations in `iris-mcp` |

All functional configuration is resolved inside IRIS. Docker Compose only
defines executable infrastructure—IRIS, Web Gateway, the frontend, and local
LLM servers. It is not the source of truth for models, agents, tools, policies,
or authorizations.

```text
%AI.Tool classes ──> %Discover() ──> IRIS catalog
                                           │
                                  agent-to-method assignment
                                           │
                                  agent-to-audit-policy assignment
                                           │
model + agent configuration ───────────────┤
                                           ▼
REST API ──> Business Service ──> Business Operation ──> %AI.Agent
                │                       │                      │
                └──── IRIS messages ────┴──── tools/policies ─┘
```

## Interoperability production

The console uses `App.Interop.Production` as the mandatory LLM call path. The API
creates an `App.Interop.Message.ChatRequest` and synchronously submits it to the
`AI Governance API Service` Business Service. The service forwards the message
to the `AI Hub LLM Operation` Business Operation. Its governed execution path is
shared with `App.Interop.AgentOperation`, which exposes agents to BPL processes.

IRIS persists request and response headers and bodies in the Message Bank. Each
request includes a `RequestId`, JWT user, agent, conversation, purpose, and
timestamp. The response retains status, error, duration, and result. The same
`RequestId` is propagated to functional chat messages and tool audit events,
which correlates the HTTP, interoperability, agent, and tool layers.

For REST calls, the API forwards the validated JWT subject explicitly in the
message. Production jobs use that forwarded identity through the job-local
context rather than substituting their own IRIS service account. The production is configured
for automatic startup during bootstrap.

### Agents as BPL Business Operations

Add `App.Interop.AgentOperation` to a production. **AgentName** is its only
application-specific setting, with a portal selector listing approved, enabled
agents from the current namespace. Multiple operation instances can select
different agents. Standard interoperability settings remain available.

Send the prompt in `Ens.StringRequest.StringValue` and read the plain-text reply
from `Ens.StringResponse.StringValue`. Each request starts an independent
conversation. The model, instructions, tools and policies come from the stored
agent definition.

This path uses the production job's IRIS identity (`$username`, usually
`_Ensemble`). Enable that identity in **AI Users** and assign it the selected
agent. No permissions are granted automatically. The text message cannot
override the identity or select a different agent.

```xml
<call name="Ask agent" target="Configured agent operation" async="0" timeout="300">
  <request type="Ens.StringRequest">
    <assign property="callrequest.StringValue" value="request.StringValue" action="set" />
  </request>
  <response type="Ens.StringResponse">
    <assign property="response.StringValue" value="callresponse.StringValue" action="set" />
  </response>
</call>
```

Change the source and destination assignments to match your own BPL contract.
The operation validates agent availability at startup and for every request.
Failures return an error `%Status` for BPL fault handling. Conversations, policies
and tool audits use the shared governed executor. The production trace retains
the original string request and response.

`iris/tests/bpl-agent/` contains a deterministic local mock LLM and a real BPL
integration test. Run it only in a disposable instance: it creates test registry
records and changes the active production.

## Secure model configuration

`App.Governance.Model` stores only governed model metadata:

- logical identity and display name;
- AI Hub provider;
- commercial model identifier or local alias;
- approval and activation state;
- declared maximum context capacity (`maxContextTokens`).

Connection fields such as `apiKey`, `baseUrl`, and `region` are stored in
`%ConfigStore.Configuration`, not as properties or columns of
`App.Governance.Model`. Every record uses an internal, stable FQN in the form
`APP.AI.MODEL.model-<id>`. This relationship is derived from the immutable model
ID, so there is no `ConfigName` field or separate configuration for users to
manage.

The API and form continue to expose the same typed fields. `Create`, `Update`,
and `ListJSON` on `App.Governance.Model` transparently write and read Config
Store. Agents add instructions, temperature, iterations, tools, delegates, policies,
input context budget and response reserve to the selected governed model.

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
  "maxContextTokens": 4096,
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
  "maxContextTokens": 4096,
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

Port `8000` is used for container-to-container communication. Host ports `8000`
and `8001` expose Llama and Qwen respectively outside the Docker network.

These records are namespace data and are not embedded in the image or
bootstrap. They must be registered again from the platform in a new database.

The capacities above match the default `.env.example`. If the server context
changes, update `maxContextTokens` to the actual endpoint capacity; editing model
metadata does not resize the server. Optional server settings and required files
are described in [models/README.md](models/README.md).

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
intersystems/iris-community:2027.1.0AI.109.0
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

On the separate `iris-demo` instance, `App.Demo.InventoryTools` publishes `SearchInventory`, which queries the
persistent `App.Demo.Inventory` table, and `AddInventoryItem`, which registers
a product from its name, unique SKU or reference, and initial quantity.

`Inventory.Name` has a full-text `NameSearchIndex` defined as an
`%iFind.Index.Basic` index with English language processing, lowercase
normalization (`INDEXOPTION=1`, `LANGUAGE="en"`, `LOWER=1`). Bootstrap builds it after seeding demo data.

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
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'en') " _
        "ORDER BY Name", name)
    return ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 25, startedAt)
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
`App.Demo.ShipmentProduct`. The `iris-demo` bootstrap creates eight shipments and 23 product
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

`POST /api/app/tools/sync` inspects compiled classes in the current core namespace
only. It does not discover the examples in `iris-demo` or `iris-mcp`; use each
registered server's `/mcp-servers/:serverName/tools/sync` route for those tools. New methods are
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

After registering a model, agent and user authorization, use the governed
application entry point so policy checks, session persistence and context budgets
are applied together:

```objectscript
set sc = ##class(App.Interop.Gateway).Send("agent-name",
    "Find products whose name contains coffee", "", $username, "example", .result, .httpStatus)
if $SYSTEM.Status.IsOK(sc) write result.content
```

The caller's IRIS user must be authorized for that agent and the application
production must be running. Creating a `%AI.Agent` directly is a lower-level SDK
operation; it does not apply the chat facade's persistence and context-budget
preparation automatically.

The factory resolves each agent's tool assignments and policies from IRIS.
`App.AIHub.Policy.DynamicAudit` composes the approved, enabled audit policies
selected on the agent and applies them to all its tool executions. The
`database-audit` policy persists events in `App.Governance.AuditEvent`.
Tools have no independent audit configuration.

## Chat and user authorization

The **Agent chat** screen can invoke any approved agent. The first call creates
a `%AI.Agent.Session`; subsequent calls reuse it to preserve context. IRIS
stores the conversation, its owning user, and its transcript.

The screen has **Chat** and **Conversation statistics** tabs. Switching tabs
preserves the conversation and unsent draft. The statistics tab shows the
conversation identifier and native `%AI.Agent.Session.GetStats()` values,
refreshed after each answer: interactions, input/output tokens, tool
calls, LLM time, context tokens and context usage. Throughput uses the SDK formula:
input plus output tokens divided by LLM time. Reasoning, cache and tool duration
are shown when active. Values accumulate within the current session and exclude
delegated agents' sessions. Missing values display as “—”; unavailable telemetry
does not turn a successful chat answer into an error.
The conversation also saves `session.Export()` and restores it with
`session.Import()` on continuation, preserving explicit context and statistics restoration across
requests. Each conversation saves its native session state after every successful answer.

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
| `GET` | `/api/app/health` | Platform health |
| `POST` | `/api/app/login` | Obtain IRIS JWTs (native handler) |
| `POST` | `/api/app/refresh` | Refresh JWTs (native handler) |
| `GET/POST` | `/api/app/ai-users` | AI user registry |
| `PUT` | `/api/app/ai-users/:username/agents` | User agent assignments |
| `GET` | `/api/app/my-agents` | Agents authorized for the caller |
| `POST` | `/api/app/chat` | Start/continue a conversation; return statistics and summary metadata |
| `GET` | `/api/app/providers` | Supported provider fields |
| `GET/POST` | `/api/app/models` | List/create models and declared capacities |
| `PUT/DELETE` | `/api/app/models/:modelName` | Update/delete model; referenced models cannot be deleted |
| `GET` | `/api/app/tools` | Local and imported MCP tool catalog |
| `POST` | `/api/app/tools/sync` | Discover compiled local tools in APP |
| `PUT` | `/api/app/tools/:toolName` | Update tool governance |
| `GET/POST` | `/api/app/policies` | Registered policies |
| `GET/POST` | `/api/app/agents` | List/create agent definitions |
| `PUT/DELETE` | `/api/app/agents/:agentName` | Update/delete agent; dependency checks apply |
| `GET/PUT` | `/api/app/agents/:agentName/tools` | Read/replace assigned tools |
| `GET` | `/api/app/agents/:agentName/catalog` | Effective agent tool catalog |
| `POST` | `/api/app/agents/:agentName/test` | Governed agent inference |
| `GET/POST` | `/api/app/mcp-servers` | List/register MCP servers |
| `PUT/DELETE` | `/api/app/mcp-servers/:serverName` | Update/delete server; assigned tools block deletion |
| `GET` | `/api/app/mcp-servers/:serverName/tools` | Imported tools for a server |
| `POST` | `/api/app/mcp-servers/:serverName/tools/sync` | Discover/refresh a remote MCP catalog |
| `GET` | `/api/app/audit-events` | Tool execution audit history |

Agent `tools`, `delegates`, `policies`, `contextBudget` and `responseReserve` are edited through the agent POST/PUT payload. Sign out in the console clears its browser JWT storage.

## Project structure

```text
iris/src/App/Governance/       # persistent governance model and validation
iris/src/App/REST/             # administrative API
iris-demo/src/                # separate inventory/shipment classes and MCP publication
iris-mcp/src/                 # separate daily-price classes and MCP publication
iris/config/                  # Config Store model descriptor compiled in %SYS
iris/src/App/AIHub/            # policies, adapter, and AI Hub factory
iris/src/App/Interop/          # production, messages, service, and operation
frontend/src/                  # React console
  i18n.tsx                     # Spanish/English catalogs and language context
webgateway/shared/             # Web Gateway configuration
```

Each IRIS image loads its own source directory; the core also installs its
Config Store descriptor in `%SYS`. AI Hub is a mandatory dependency.

## External MCP servers

The deployment includes `iris-demo` for inventory/shipments and an independent
`iris-mcp` pricing instance using the same IRIS
image as the backend and its own persistent databases. A native
`%AI.MCP.Service` publishes only `SearchInventory` and `GetDailyPrices`.
The external demo has one persistent class, `External.Demo.Price`, containing
product name, date, price and currency, with no relationships. Both queries
use the same iFind index as `App.Demo.Inventory`. Prices are synthetic EUR values.
The `iris-mcp-transport` container
runs the official `iris-mcp-server` binary and exposes HTTP MCP at
`http://localhost:8082/mcp`, bound to the local host interface.

The **MCP servers** console tab registers and edits external endpoints,
authentication and lifecycle states. The test endpoint reachable from the
backend is `http://iris-mcp-transport:8080/mcp`. Bearer tokens must be
`secret://...` references resolved from Secure Wallet.

For each approved, enabled server, the refresh icon (**Discover tools** tooltip) retrieves the complete MCP
catalog, including pagination. The list icon (**View tools**) opens a wide modal
with search by name/description and parameter definitions. Imported tools appear in the tool catalog
with their server of origin and can be selected when editing an agent. Only
assigned tools are exposed to that agent, under its authorization and audit
policies.

Synchronization preserves local names, assignments and lifecycle states. New
tools are approved and enabled, matching local catalog discovery. Removed tools
become unavailable; a failed discovery preserves the previous catalog.
Suspending or disabling a server blocks its tools. Changing its URL or
authentication requires rediscovery.

The API exposes `GET/POST /api/app/mcp-servers` and
`PUT /api/app/mcp-servers/:serverName`, plus
`POST /api/app/mcp-servers/:serverName/tools/sync` for discovery and
`GET /api/app/mcp-servers/:serverName/tools` for the imported catalog. Servers
persist in `App.Governance.MCPServer`; tools persist in `App.Governance.Tool`
with their local or MCP origin. The client uses Streamable HTTP, JSON or SSE
responses and short-lived sessions. HTTPS verifies certificates through the
`APP.MCP.Client` TLS configuration. See [iris-mcp/README.md](iris-mcp/README.md)
for setup and validation.

## Frontend development

```powershell
Set-Location frontend
npm ci
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

## Image prerequisite

The default image is `intersystems/iris-community:2027.1.0AI.109.0`. Import the
AI Hub EAP image with `docker load -i <archive>` and use its loaded tag as
`IRIS_IMAGE`, or assign the project's default tag locally. The same image is
used by all three IRIS builds and both MCP transports. It must include the AI Hub
SDK and `iris-mcp-server`; floating preview tags may have different contents.

The initial core build installs `App.AIHub.Config.ModelDescriptor` in `%SYS`,
registers the Config Store schema and compiles all application classes. Each
example image builds and seeds only its own namespace. See [Startup](#startup).

## Agent context budgets

Models declare `maxContextTokens`, the actual total capacity served by the LLM
endpoint. This is metadata for validation, not a remote server setting. For the
local Llama service, keep it aligned with `LLM_CONTEXT_SIZE` in Compose; changing
that environment setting requires recreating Llama. New model registrations default to 4096 tokens when omitted; declare the real
capacity for each endpoint.

Agents declare `contextBudget` (input) and `responseReserve` (maximum generated
tokens **per model call**). Input includes system instructions, tool/delegate
schemas, conversation history, tool results and the new user message.
`contextBudget + responseReserve` must not exceed model capacity. A budget of 0
inherits `maxContextTokens - responseReserve`; the default reserve is 1024.
For example, a 16384-token endpoint can serve an agent with an input budget of
12000 and a response reserve of 2048. Reducing model capacity is rejected if an
assigned agent would no longer fit.

Before each user message, the Orchestrator checks the input using a conservative
estimate of one token per three UTF-8 bytes plus framing headroom, not the
provider's exact tokenizer. Actual tokenization can differ, so this admission
check is not a strict token guarantee and may summarize early. When
needed, the primary mechanism is `session.Summarize(provider, model, 1, prompt)`.
The SDK produces structured conversation memory and explicitly retains the latest
message. In preview build 109, passing 0 instead selects the default of ten recent
messages. Summarization replaces only the native session context. The full persisted
chat transcript and cumulative session statistics remain available. Summary
requests incur additional model calls and are not included in the native chat
session's token statistics. If the fixed instructions/tools/new message cannot
fit, or summarization fails, the request returns an error without silently
truncating or replacing the persisted conversation state.

The block-based implementation is a fallback only. A real Llama test with a
16384-token endpoint showed that native `Summarize()` forwards an oversized
transcript in one request: roughly 20000 tokens were rejected with
`exceed_context_size_error`. Blocks are therefore used only for that explicit
provider error, or when a successful SDK summary still exceeds the agent budget
(for example, because its retained latest message is too large). The original
snapshot is restored before fallback, and a small completed latest assistant
answer is retained verbatim when it fits. Other SDK/provider errors propagate without
a block retry. The response exposes `contextManagement.summaryMethod` as `none`,
`sdk` or `blocks`.

This admission check runs at the start of each chat turn. Tool results generated
inside that turn are handled by the SDK's `auto_compact_on_token_limit` safeguard;
the agent input budget is not a hard token counter between native tool iterations.
It does not guarantee admission of a single oversized tool result. Keep tool
outputs bounded and the declared endpoint capacity accurate. The chat statistics
panel shows declared capacity, input budget, response reserve and whether history
was summarized before the last message.

See [context regression tests](iris/tests/context-budget/README.md) for isolated validation.

## Deleting registry entries and summary history

The chat statistics retain the last summary's server timestamp, method (SDK
Summarize or blocks) and count across subsequent messages in that conversation.
Before the first summary, no summary timestamp is shown. The last-send flag remains separate from the last recorded summary.

Models, agents and MCP server registrations have a Delete action with a
confirmation modal identifying the resource type, display name and logical
name. Edit/delete actions use pencil/trash icons with tooltips. The API provides
`DELETE /api/app/models/:name`, `DELETE /api/app/agents/:name`
and `DELETE /api/app/mcp-servers/:name`. A model cannot be deleted while any agent
references it, regardless of status. An MCP server cannot be deleted while any
of its tools is assigned to an agent. These checks also apply to direct API
calls and return HTTP 409 with the dependency; missing entries return 404.

Deleting an unused MCP registration removes its discovered catalog tools and
leaves the remote server running. Agent deletion is blocked by incoming delegate
assignments or configured production AgentName settings; otherwise its tool,
outgoing delegate and user assignments are removed. Chat transcripts and audit
history remain. Deleting an unused model removes its connection configuration;
it does not stop the LLM server or delete model files.

## MCP discovery troubleshooting

MCP transports wait for the IRIS superserver socket before starting the native
client. In preview build 109, starting offline and reconnecting can leave native
service discovery returning HTTP 401. If discovery returns only `iris_status`
with an empty schema, check the transport logs and authentication, then restart
the transports after IRIS is ready:

```powershell
docker compose restart iris-demo-transport iris-mcp-transport
```

The Orchestrator rejects that invalid diagnostic descriptor without replacing
the existing catalog. The View tools and Discover tools actions use list and
refresh icons with tooltips and accessible names.

## First-install validation

This repository targets new installations. Start with empty durable directories (`iris/shared`, `iris-demo/shared`, and `iris-mcp/shared`). The initial build creates the schemas, native configuration and seed data; it does not convert existing deployments.

Before loading test fixtures, verify a disposable core instance without persistent volumes:

```powershell
docker run -d --name ai-orchestrator-first-install-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Wait for the IRIS startup-complete message.
Get-Content -Raw iris/tests/first-install.script | docker exec -i ai-orchestrator-first-install-test iris session IRIS
docker rm -f ai-orchestrator-first-install-test
```

Expected marker: `FIRST_INSTALL_FAILURES=0`. The check verifies empty application catalogs, initial policies and administrator, the separation of business examples, and repeatable bootstrap initialization.
