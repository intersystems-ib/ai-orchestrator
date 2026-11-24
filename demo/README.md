# Agent concepts and a simple Slidev demonstration

**English** | [Español](README_es.md)

The Spanish-language presentation has 19 slides with speaker notes, organized as:
concepts (agent, tool, LLM, MCP); InterSystems AI Hub and MCP; a final AI Orchestrator
inventory-and-pricing example. It introduces the practical scenario only in the
final section, with an editable architecture diagram and a copyable prompt.
The main talk excludes BPL, shipment queries, permission changes and failure drills.

## Starting the presentation

```powershell
docker compose --profile demo up -d --build demo
```

Open [the presentation](http://localhost:3030). `DEMO_PORT` changes its port.
The presentation has no startup dependencies and creates no agents, models,
users or permissions. Start application services separately when needed:

```powershell
docker compose up -d --build iris iris-demo iris-demo-transport iris-mcp iris-mcp-transport webgateway frontend
# Optional local models; requires the model files and GPU resources:
docker compose --profile ai up -d llama qwen
```

For local hot-reload editing, run `npm ci` then `npm run dev` in `demo/`.
Node 24.11 or later is required. The lockfile pins the dependencies; compatible
DOMPurify and image-size overrides include the fixes applied when Slidev was added.
The deck still works without a backend. Its health check only queries
`/api/app/health`: it does not authenticate or test inference, and a login
requirement does not prove the agent is ready.

## Functional preparation

1. Sign in with an enabled demonstration user.
2. Register an approved model already verified to support tool calling and test
   its provider connection.
3. Register and discover `iris-demo` using
   `http://iris-demo-transport:8080/mcp` from the Docker backend.
4. Prepare an approved, enabled `demo-operaciones` agent with the inventory
   `SearchInventory` tool from that server and the chosen model.
5. Assign its `database-audit` policy; user authorization is mandatory.
6. In **AI users**, enable the demonstration user and assign that agent.
7. Register/discover `iris-mcp-demo` at
   `http://iris-mcp-transport:8080/mcp` and assign its `GetDailyPrices` tool.
8. Check that the chosen day has quotations. Add missing recent sample days with:

```powershell
Get-Content -Raw demo/scripts/seed-prices.script | docker compose exec -T iris-mcp iris session IRIS
```

Prices are fictional EUR values. Seeding preserves existing names, dates and
amounts. Inventory sample names are English: use `Coffee` or `Rice`. The selected
quotation day is shared by the prompt scenarios and retained in the browser
session. If a day has no prices, report their absence.

Suggested agent instructions:

```text
Answer in Spanish. Use assigned tools for operational data. Do not invent stock,
prices, dates or IDs. Report missing data or access. When combining inventory and
prices, show the quotation day and explain ambiguities in product-name matching.
```

## Speaker guide

Allow 20–25 minutes, including the live query. Detailed notes are in `slides.md`
and Slidev's presenter view (toolbar or `/presenter`).

| Block | Slides | Purpose |
|---|---|---|
| Concepts | 1–6 | Define the four terms without introducing the example |
| Platform | 7–14 | SDK, agents, tools, policies, XML and MCP publication |
| Demonstration | 15–18 | AI Orchestrator, system diagram, query and audit |
| Recap | 19 | Relate the concepts to the observed behavior |

Prepare configuration before the session. Show the agent and its two assigned
tools, optionally identify the MCP servers, send the prompt on slide 17 and check
inventory/prices and corresponding audit calls. The example combines two remote
MCP sources, business inventory and dated prices. The main query does not change
stock, permissions or service availability. Reserve configuration forms, BPL and
technical diagnosis for later questions. Product-name matching is a simplification;
a real deployment should define identifiers and correspondence rules.

Links open frontend anchors such as `#models`, `#agents`, `#mcp`, `#chat` and
`#audit`. Authentication remains mandatory. Reuse the existing console tab for
chat continuity. The optional `LiveConsole` component can embed the console.

## Optional BPL extension

BPL is outside the introductory deck. To prepare a separate technical demo:
manually import
`demo/snippets/AgentDemoProcess.cls` into `APP`. This declares a process but does
not start or modify a production. In a demonstration production, add an
`App.Interop.AgentOperation` named **Demo Agent Operation**, select
`demo-operaciones` through `AgentName`, and add `App.Demo.AgentProcess` plus an
input service/test mechanism sending `Ens.StringRequest`. Authorize the production
job's IRIS user (usually `_Ensemble`) for the agent. Send the prompt through
`StringValue`; read `Ens.StringResponse.StringValue` and the portal trace.
The BPL process is a demonstration snippet, not a business data class baked into
the core image. Do not deploy the disposable `iris/tests/bpl-agent/` production
in a persistent demonstration environment: it changes production and permissions.

## Addresses, build and export

Docker browser URLs use the root `.env` ports. For npm development, copy
`.env.example` to `.env.local` in this directory and configure:

| Variable | Purpose |
|---|---|
| `VITE_ORCHESTRATOR_URL` | Console URL opened by the browser |
| `VITE_IRIS_PORTAL_URL` | Core IRIS portal |
| `VITE_MCP_PORTAL_URL` | Pricing IRIS portal |
| `DEMO_PROXY_TARGET` | Internal health proxy destination |

Do not place passwords, API keys or JWTs in slides or these files. The proxy
target is not a browser URL. For a remote presentation machine, configure public
URLs and service access explicitly. The presentation port defaults to loopback.

```powershell
cd demo
npm test
npm run build
npm run build:public
# Optional PDF; requires Slidev's Playwright browser:
npm run export
```

`dist/` contains the static SPA; its web server must resolve client routes.
Console links still need a reachable backend. `/demo-api/health` requires the dev
proxy or an equivalent published proxy. A PDF does not preserve browser
interactions. No mandatory remote fonts are used.

References: [Slidev](https://sli.dev/guide/),
[Vite customization](https://sli.dev/custom/config-vite),
[directory structure](https://sli.dev/custom/directory-structure),
[hosting](https://sli.dev/guide/hosting).

The selected model must declare the endpoint's actual `maxContextTokens` (Llama
16384 and Qwen 4096 with the default Compose settings). Configure the agent's
input budget and response reserve accordingly. The chat has separate Chat and
Conversation statistics tabs, and retains the draft when switching. MCP actions
are list/refresh icons with tooltips; view tools in their modal.
