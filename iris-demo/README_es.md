# Ejemplos de negocio independientes

[English](README.md) | **Español**

Esta instancia IRIS contiene el inventario, las cabeceras de envío y sus líneas.
AI Orchestrator consume sus herramientas por MCP. Tiene namespace `DEMO`, bases
`DEMO_CODE` / `DEMO_DATA` y almacenamiento propio en `shared/durable`. Utiliza
la misma `IRIS_IMAGE` que el núcleo y el servidor de cotizaciones.

```powershell
docker compose up -d --build iris-demo iris-demo-transport
```

| Conexión | Dirección por defecto |
|---|---|
| MCP desde Orchestrator | `http://iris-demo-transport:8080/mcp` |
| MCP desde el equipo | `http://localhost:8083/mcp` |
| Portal de gestión | `http://localhost:52775/csp/sys/UtilHome.csp` |
| Superserver desde el equipo | `localhost:1974` |

Los puertos del equipo se publican en loopback. Se configuran con
`IRIS_DEMO_WEB_PORT`, `IRIS_DEMO_SUPERSERVER_PORT` y `DEMO_MCP_HTTP_PORT`.
`IRIS_DEMO_USERNAME` / `IRIS_DEMO_PASSWORD` identifican una cuenta ya existente
en IRIS. En desarrollo se usa `CSPSystem/SYS`; cada despliegue debe provisionar
su propia cuenta y permisos. El endpoint `/mcp/business` exige autenticación
Password. El binario oficial `iris-mcp-server` utiliza esas credenciales; el
transporte reutiliza el proxy de validación de la cabecera Host de `iris-mcp/serve.py`.

`Demo.MCP.Tools` extiende `%AI.ToolSet` e incluye explícitamente los cuatro métodos en su `Definition` XML;
`Demo.MCP.Service` la referencia mediante `SPECIFICATION`. Se publican:

| Herramienta | Entradas | Función |
|---|---|---|
| `mcp_business_SearchInventory` | `name` | Búsqueda iFind en inglés; ID, SKU, nombre y stock |
| `mcp_business_AddInventoryItem` | `name`, `sku`, `quantity` | Alta o incremento de stock, conservando el SKU existente |
| `mcp_business_SearchShipmentsByProduct` | `productId` | Líneas de envío de un ID de producto |
| `mcp_business_SearchShipmentsByDateRange` | `startDate`, `endDate` opcionales | Rango inclusivo por fecha de envío `YYYY-MM-DD` |

Las instalaciones nuevas cargan 20 productos con nombres en inglés, ocho envíos
y 23 líneas. Inventario y cotizaciones utilizan `NameSearchIndex` con
`LANGUAGE="en"`; las consultas SQL seleccionan explícitamente ese índice.
Las búsquedas de ejemplo usan `Coffee` o `Rice`. Las cotizaciones son ficticias.

En **Servidores MCP**, registra `iris-demo`, apruébalo y habilítalo, descubre el
catálogo y asigna sus herramientas a los agentes. Las policies de autorización
y auditoría permanecen en cada agente del Orchestrator. Publicar el alta de stock
no la asigna automáticamente. El bootstrap principal no carga datos de negocio
ni registra automáticamente este servidor de ejemplo.

```powershell
./iris-demo/tests/smoke.ps1
```

La prueba verifica los cuatro métodos MCP. El alta añade cero unidades a un
producto de ejemplo existente, conservando el inventario. Las pruebas locales
del runtime cargan explícitamente las clases de negocio como fixtures; nunca
se incluyen en la imagen del Orchestrator.

## Configurar la publicación en IRIS

La publicación se declara explícitamente mediante `%AI.ToolSet` para incluir solo los métodos deseados. En esta preview, la clase contenedora no descubre métodos únicamente por heredarlos.

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

La clase de servicio enlaza el contrato de herramientas con el endpoint:

```objectscript
Class Demo.MCP.Service Extends %AI.MCP.Service
{
Parameter SPECIFICATION As STRING = "Demo.MCP.Tools";
}
```

Compila las clases de herramientas de negocio antes que el ToolSet XML: su generador resuelve los métodos incluidos durante la compilación. La construcción de la imagen aplica este orden y comprueba el número de herramientas publicadas.

Después de compilar, registra la aplicación en `%SYS` (ya lo hace `iris.script`):

```objectscript
set properties("Type")=18
set properties("NameSpace")="DEMO"
set properties("DispatchClass")="Demo.MCP.Service"
set properties("Enabled")=1
set properties("AutheEnabled")=32
set properties("MatchRoles")=":%All"
set sc=##class(Security.Applications).Create("/mcp/business",.properties)
```

Configura el transporte en `config.toml`; las credenciales proceden del entorno:

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

La ruta interna de IRIS y la ruta HTTP `/mcp` son distintas. La cuenta debe tener permisos sobre las clases y datos publicados. Si la aplicación ya existe, actualiza su configuración en el portal en lugar de crearla otra vez.

## Añadir el servidor en AI Orchestrator

1. Abre **Servidores MCP** y pulsa **Registrar servidor**.
2. Usa nombre `iris-demo`, URL `http://iris-demo-transport:8080/mcp`, transporte `streamable-http`, autenticación `none`, estado `approved` y habilitado.
3. Guarda y pulsa el icono de actualización (**Descubrir herramientas**). El icono de lista (**Ver herramientas**) abre el modal con búsqueda de nombres y parámetros.
4. En **Agentes**, edita el agente y selecciona las herramientas remotas permitidas. Configura sus policies y autoriza al usuario en **Usuarios IA**.
5. Abre el chat y prueba una consulta con `Coffee`. La auditoría del agente registra las llamadas.

También puedes usar la API autenticada. Cuerpo de `POST /api/app/mcp-servers`:

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

Después ejecuta `POST /api/app/mcp-servers/iris-demo/tools/sync`. La respuesta incluye las tools importadas; asígnalas mediante la edición del agente o `PUT /api/app/agents/:agentName/tools`. Consulta `GET /api/app/mcp-servers/iris-demo/tools`.

`authMode: none` corresponde al transporte de esta red Docker de ejemplo: las credenciales anteriores autentican el transporte frente a IRIS. No implica autenticación del cliente MCP. Para un endpoint protegido por un gateway que valide Bearer, configura `authMode: bearer` y `bearerSecret: secret://<referencia>` del Secure Wallet; no pongas el token en JSON ni en Git.
