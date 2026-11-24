# Isolated business examples

**English** | [Español](README_es.md)

This IRIS instance owns the inventory, shipment headers and shipment lines.
AI Orchestrator only consumes its tools over MCP. It has its own `DEMO`
namespace, `DEMO_CODE` / `DEMO_DATA` databases and `shared/durable` storage.
It uses the same `IRIS_IMAGE` as the core and pricing servers.

```powershell
docker compose up -d --build iris-demo iris-demo-transport
```

| Connection | Default address |
|---|---|
| MCP from Orchestrator | `http://iris-demo-transport:8080/mcp` |
| MCP from the host | `http://localhost:8083/mcp` |
| Management Portal | `http://localhost:52775/csp/sys/UtilHome.csp` |
| Superserver from the host | `localhost:1974` |

Host ports bind to loopback. Override them with `IRIS_DEMO_WEB_PORT`,
`IRIS_DEMO_SUPERSERVER_PORT` and `DEMO_MCP_HTTP_PORT`. Configure the existing
IRIS account through `IRIS_DEMO_USERNAME` / `IRIS_DEMO_PASSWORD`. Development
credentials default to `CSPSystem/SYS`; deployments must provision their own
account and permissions. The MCP endpoint `/mcp/business` requires password
authentication. The official `iris-mcp-server` connects with those credentials;
the transport reuses the HTTP host-validation proxy in `iris-mcp/serve.py`.

`Demo.MCP.Tools` extends `%AI.ToolSet` and explicitly includes the four methods in its XML `Definition`. `Demo.MCP.Service`
references it through `SPECIFICATION`. The catalog exposes exactly:

| Tool | Inputs | Behavior |
|---|---|---|
| `mcp_business_SearchInventory` | `name` | English iFind name search; ID, SKU, name and stock |
| `mcp_business_AddInventoryItem` | `name`, `sku`, `quantity` | Add a product or increase existing stock; preserve its original SKU |
| `mcp_business_SearchShipmentsByProduct` | `productId` | Shipment lines for an inventory product ID |
| `mcp_business_SearchShipmentsByDateRange` | optional `startDate`, `endDate` | Inclusive shipping date range, formatted `YYYY-MM-DD` |

New installations seed 20 English product names, eight shipments and 23 lines.
Both inventory and the separate pricing example use `NameSearchIndex` with
`LANGUAGE="en"`, and their SQL explicitly selects this index. Search for
`Coffee` or `Rice`. All quotation values are synthetic.

In **MCP servers**, register `iris-demo`, approve and enable it, discover the
catalog and explicitly assign tools to agents. Authorization and audit policies
stay on each Orchestrator agent. Publishing the stock-writing method does not
automatically assign it. The core bootstrap neither seeds business data nor
registers this example server.

```powershell
./iris-demo/tests/smoke.ps1
```

The smoke test verifies all four MCP methods. Its stock update adds zero units
to an existing sample item, leaving the inventory unchanged. Disposable local
runtime tests explicitly load business fixtures; they are never baked into the
Orchestrator image.

## Configuring publication in IRIS

Declare publication explicitly through `%AI.ToolSet` to include only the intended methods. In this preview, a wrapper class does not discover methods simply by inheriting them.

```objectscript
/// Explicitly publish the four business methods, including their input schemas.
Class Demo.MCP.Tools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="BusinessExamples">
  <Description>Inventory and shipment operations</Description>
  <Include Class="App.Demo.InventoryTools" Tool="SearchInventory"/>
  <Include Class="App.Demo.InventoryTools" Tool="AddInventoryItem"/>
  <Include Class="App.Demo.ShipmentTools" Tool="SearchShipmentsByProduct"/>
  <Include Class="App.Demo.ShipmentTools" Tool="SearchShipmentsByDateRange"/>
</ToolSet>
}
}
```

The service class binds the tool specification to the endpoint:

```objectscript
Class Demo.MCP.Service Extends %AI.MCP.Service
{
Parameter SPECIFICATION As STRING = "Demo.MCP.Tools";
}
```

Compile the business tool classes before the XML ToolSet: its generator resolves included methods at compile time. The image build enforces this order and checks the published tool count.

After compilation, register the application in `%SYS` (`iris.script` already does this):

```objectscript
set properties("Type")=18
set properties("NameSpace")="DEMO"
set properties("DispatchClass")="Demo.MCP.Service"
set properties("Enabled")=1
set properties("AutheEnabled")=32
set properties("MatchRoles")=":%All"
set sc=##class(Security.Applications).Create("/mcp/business",.properties)
```

Configure the transport in `config.toml`; credentials come from the environment:

```toml
[mcp]
transport = "http"
host = "127.0.0.1"
port = 8081
base_route = "/mcp"
allowed_hosts = ["iris-demo-transport:8080", "localhost", "127.0.0.1"]
[[iris]]
name = "business"
server = { host = "iris-demo", port = 1972, username = "@{env:IRIS_DEMO_USERNAME}", password = "@{env:IRIS_DEMO_PASSWORD}" }
pool = { min = 1, max = 3 }
endpoints = [{ path = "/mcp/business", username = "@{env:IRIS_DEMO_USERNAME}", password = "@{env:IRIS_DEMO_PASSWORD}" }]
```

The internal IRIS application path differs from HTTP `/mcp`. The account must have access to the published classes and data. If the application already exists, edit it in the portal instead of creating it again.

## Adding the server to AI Orchestrator

1. Open **MCP servers** ("Servidores MCP") and choose **Register server**.
2. Set name `iris-demo`, URL `http://iris-demo-transport:8080/mcp`, transport `streamable-http`, authentication `none`, status `approved`, and enabled.
3. Save and choose the refresh icon (**Discover tools** tooltip). The list icon (**View tools**) opens the searchable tools modal.
4. Edit the agent, assign the permitted remote tools, select its policies and authorize the user in **AI users**.
5. Open chat and query `Coffee`. Agent auditing records tool calls.

Alternatively use the authenticated API. Body for `POST /api/app/mcp-servers`:

```json
{
  "name": "iris-demo",
  "displayName": "Business examples",
  "endpointUrl": "http://iris-demo-transport:8080/mcp",
  "transport": "streamable-http",
  "authMode": "none",
  "status": "approved",
  "enabled": true
}
```

Then call `POST /api/app/mcp-servers/iris-demo/tools/sync`. The response includes imported tools; assign them using the agent editor or `PUT /api/app/agents/:agentName/tools`. Inspect them with `GET /api/app/mcp-servers/iris-demo/tools`.

`authMode: none` applies to this Docker example transport: the credentials above authenticate the transport to IRIS, not the MCP client. For an endpoint behind a gateway that validates Bearer authentication, use `authMode: bearer` and a Secure Wallet `bearerSecret: secret://<reference>`; never commit tokens or include plaintext tokens in registry JSON.
