# External IRIS pricing MCP server

**English** | [Español](README_es.md)

An independent IRIS instance publishes synthetic daily product quotations with
AI Hub's native MCP server. It uses `IRIS_IMAGE`, namespace `MCP`, separate
`MCP_CODE` / `MCP_DATA` databases and `iris-mcp/shared/durable` persistence.
Inventory and shipments belong to the separate `iris-demo` server.

`External.MCP.Service` extends `%AI.MCP.Service`, using `External.MCP.Tools` as
its specification. This `%AI.ToolSet` class explicitly includes methods from `External.Demo.InventoryTools` in XML and exposes
exactly two methods. The IRIS application `/mcp/demo` requires password authentication.

```powershell
docker compose up -d --build iris-mcp iris-mcp-transport
```

| Connection | Default address |
|---|---|
| MCP from Orchestrator | `http://iris-mcp-transport:8080/mcp` |
| MCP from the host | `http://localhost:8082/mcp` |
| Management Portal | `http://localhost:52774/csp/sys/UtilHome.csp` |
| Superserver from the host | `localhost:1973` |

`iris-mcp-transport` runs the official `iris-mcp-server` binary. The bundled
version requires a loopback HTTP host, so `serve.py` forwards requests from
port 8080 to the binary on loopback port 8081, preserving authentication,
sessions and streaming while validating hosts. Both example servers reuse
this proxy. It does not implement business tools.

`config.toml` gets connection credentials from `IRIS_MCP_USERNAME` and
`IRIS_MCP_PASSWORD`; development defaults are `CSPSystem/SYS`. The account must
already exist in IRIS. The host MCP port binds to loopback. Before deployment,
provision appropriate credentials and access controls for the intended environment.

## Product quotations

`External.Demo.Price` is the only persistent business data class in this server:
`Name`, `Day`, `Price`, `Currency`. It has no inventory relationship, SKU or stock.
A unique `(Name, Day)` index avoids duplicate daily quotes. `NameSearchIndex` is
`%iFind.Index.Basic(INDEXOPTION=1,LANGUAGE="en",LOWER=1)`, matching the inventory
server's index. Queries explicitly use `search_index(NameSearchIndex,?,1,'en')`.
This is word-based full-text matching.

- `mcp_demo_SearchInventory(name)` lists distinct matching product names.
- `mcp_demo_GetDailyPrices(name,day)` returns `name`, `day`, `count`, `prices`.
  Each quotation includes ID, name, day, price and currency. There is no result
  truncation. Missing matches return an empty array and count zero. Empty names
  and invalid `YYYY-MM-DD` dates are rejected.

Example: `{"name":"Coffee","day":"2026-11-23"}`. Choose a date present in the data.
The seed creates seven days of fictional EUR prices for 20 English product names,
ending on the build/seed date. It preserves existing prices and does not refresh
automatically. Rerun `External.Demo.Bootstrap.Seed()` to add missing recent dates.

## Using the catalog

Register an approved, enabled server in **MCP servers**, discover its tools and
explicitly assign them to agents. Discovery and invocation use the existing
Orchestrator MCP client (Streamable HTTP, JSON/SSE, pagination and verified HTTPS
through `APP.MCP.Client`). Audit policies belong to the agent.

Rediscovery preserves tool identities, assignments and lifecycle states; missing
tools become unavailable. Connection failures preserve the previous catalog.
Suspending/disabling a server blocks its tools at execution time. Endpoint or
authentication changes require rediscovery. Bearer credentials use Secure Wallet
`secret://` references. Server registrations are persisted application data and
are not automatically created by Compose or the core bootstrap.

API: `POST /api/app/mcp-servers/:serverName/tools/sync` discovers tools;
`GET /api/app/mcp-servers/:serverName/tools` lists imported tools.

## Verification

```powershell
./iris-mcp/tests/smoke.ps1
docker cp iris-mcp/tests/InventoryTest.cls ai-orchestrator-iris-mcp:/tmp/InventoryTest.cls
Get-Content -Raw iris-mcp/tests/inventory.script | docker compose exec -T iris-mcp iris session IRIS
Get-Content -Raw iris/tests/mcp-tools.script | docker compose exec -T iris iris session IRIS
```

The HTTP smoke test checks the exact two-method catalog, search, daily quotations
and invalid-date rejection. The class test covers iFind, day filtering, validation,
additional matching products and seed idempotence, rolling back test records.
Core tests `mcp-registry.script`, `mcp-protocol.py`, `mcp-tools.script` and
`mcp-prices.script` cover registry validation, JSON/SSE/pagination/Unicode/auth,
governed execution and auditing. They roll back temporary application records;
`mcp-prices.script` invokes the remote tool through ToolManager without LLM inference; both execution scripts expect the registered server `iris-mcp-demo` and seeded quotation dates. See the scripts before
running them on a persistent deployment.

## Configuring publication in IRIS

Declare publication explicitly through `%AI.ToolSet` to include only the intended methods. In this preview, a wrapper class does not discover methods simply by inheriting them.

```objectscript
/// Explicit product-name and daily-price tool publication.
Class External.MCP.Tools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="ExternalIRIS">
  <Description>Product names and daily quotations</Description>
  <Include Class="External.Demo.InventoryTools" Tool="SearchInventory"/>
  <Include Class="External.Demo.InventoryTools" Tool="GetDailyPrices"/>
</ToolSet>
}
}
```

The service class binds the tool specification to the endpoint:

```objectscript
Class External.MCP.Service Extends %AI.MCP.Service
{
Parameter SPECIFICATION As STRING = "External.MCP.Tools";
}
```

Compile the business tool classes before the XML ToolSet: its generator resolves included methods at compile time. The image build enforces this order and checks the published tool count.

After compilation, register the application in `%SYS` (`iris.script` already does this):

```objectscript
set properties("Type")=18
set properties("NameSpace")="MCP"
set properties("DispatchClass")="External.MCP.Service"
set properties("Enabled")=1
set properties("AutheEnabled")=32
set properties("MatchRoles")=":%All"
set sc=##class(Security.Applications).Create("/mcp/demo",.properties)
```

Configure the transport in `config.toml`; credentials come from the environment:

```toml
[mcp]
transport = "http"
host = "127.0.0.1"
port = 8081
base_route = "/mcp"
allowed_hosts = ["iris-mcp-transport:8080", "localhost", "127.0.0.1"]
[[iris]]
name = "external"
server = { host = "iris-mcp", port = 1972, username = "@{env:IRIS_MCP_USERNAME}", password = "@{env:IRIS_MCP_PASSWORD}" }
pool = { min = 1, max = 3 }
endpoints = [{ path = "/mcp/demo", username = "@{env:IRIS_MCP_USERNAME}", password = "@{env:IRIS_MCP_PASSWORD}" }]
```

The internal IRIS application path differs from HTTP `/mcp`. The account must have access to the published classes and data. If the application already exists, edit it in the portal instead of creating it again.

## Adding the server to AI Orchestrator

1. Open **MCP servers** ("Servidores MCP") and choose **Register server**.
2. Set name `iris-mcp-demo`, URL `http://iris-mcp-transport:8080/mcp`, transport `streamable-http`, authentication `none`, status `approved`, and enabled.
3. Save and choose the refresh icon (**Discover tools** tooltip). The list icon (**View tools**) opens the searchable tools modal.
4. Edit the agent, assign the permitted remote tools, select its policies and authorize the user in **AI users**.
5. Open chat and query `Coffee`. Agent auditing records tool calls.

Alternatively use the authenticated API. Body for `POST /api/app/mcp-servers`:

```json
{
  "name": "iris-mcp-demo",
  "displayName": "Daily prices",
  "endpointUrl": "http://iris-mcp-transport:8080/mcp",
  "transport": "streamable-http",
  "authMode": "none",
  "status": "approved",
  "enabled": true
}
```

Then call `POST /api/app/mcp-servers/iris-mcp-demo/tools/sync`. The response includes imported tools; assign them using the agent editor or `PUT /api/app/agents/:agentName/tools`. Inspect them with `GET /api/app/mcp-servers/iris-mcp-demo/tools`.

`authMode: none` applies to this Docker example transport: the credentials above authenticate the transport to IRIS, not the MCP client. For an endpoint behind a gateway that validates Bearer authentication, use `authMode: bearer` and a Secure Wallet `bearerSecret: secret://<reference>`; never commit tokens or include plaintext tokens in registry JSON.
