# IRIS MCP externo

[English](README.md) | **Español**

Instancia independiente para publicar herramientas mediante el servidor MCP
nativo de AI Hub. Utiliza la misma variable `IRIS_IMAGE` y el mismo patrón de
Dockerfile que `iris/`, con namespace `MCP`, bases `MCP_CODE` y `MCP_DATA` y
persistencia propia en `iris-mcp/shared/durable/`.

`External.MCP.Service` extiende `%AI.MCP.Service` y publica exclusivamente
`SearchInventory` y `GetDailyPrices`, incluidas desde `External.Demo.InventoryTools` mediante el XML de `%AI.ToolSet`
por `External.MCP.Tools`. No se publican herramientas de diagnóstico ni de alta
de stock. El endpoint IRIS `/mcp/demo` requiere autenticación Password. Su registro
se crea durante la construcción de la imagen, después de compilar las clases.

El servicio `iris-mcp-transport` ejecuta el binario oficial `iris-mcp-server`
de la misma imagen, conecta con `iris-mcp:1972` y expone el transporte HTTP MCP:

La versión incluida del binario solo admite hosts HTTP de loopback. `serve.py`
lo ejecuta en `127.0.0.1:8081` y publica la entrada en el puerto `8080` del mismo
contenedor. Esta entrada comprueba los hosts permitidos de `config.toml`,
preserva autenticación, sesiones y streaming y reenvía al binario por loopback.
Esto permite conectar desde la red Docker sin modificar el SDK ni añadir otro
contenedor.

| Acceso | Dirección por defecto |
|---|---|
| MCP desde el backend | `http://iris-mcp-transport:8080/mcp` |
| MCP desde el equipo local | `http://localhost:8082/mcp` |
| Portal de la instancia MCP | `http://localhost:52774/csp/sys/UtilHome.csp` |
| Superserver desde el equipo local | `localhost:1973` |

El puerto HTTP MCP se publica solamente en la interfaz local del equipo.
`config.toml` obtiene las credenciales de conexión de `IRIS_MCP_USERNAME` y
`IRIS_MCP_PASSWORD`; los valores por defecto corresponden al usuario de
desarrollo `CSPSystem/SYS`. Cambiar estas variables requiere que el usuario
correspondiente ya exista en el IRIS externo.

```powershell
docker compose up -d --build iris-mcp iris-mcp-transport
```

En la pestaña **Servidores MCP** de la consola se puede registrar este endpoint
y otros servidores externos. El registro guarda nombre, descripción, URL,
transporte Streamable HTTP, autenticación y ciclo de vida. El modo Bearer
acepta únicamente referencias `secret://...` de Secure Wallet.

Para utilizar las herramientas:

1. Registra el servidor con estado `approved` y habilítalo.
2. Pulsa **Descubrir herramientas** para consultar e importar su catálogo.
3. Usa **Ver herramientas** para buscar por nombre o descripción y consultar
   los parámetros publicados.
4. Edita un agente y selecciona las tools remotas que podrá ejecutar. Las
   policies de auditoría se configuran exclusivamente en ese agente.

La sincronización conserva las asignaciones y estados existentes; las tools
nuevas se incorporan aprobadas y habilitadas, igual que en el descubrimiento
local. Los nombres locales incorporan la identidad del servidor para evitar
colisiones entre servidores que publican el mismo método. El nombre remoto
original se conserva para `tools/call`.

Las tools retiradas del servidor se marcan no disponibles. Los fallos de
conexión o de protocolo no sustituyen el catálogo anterior. Un servidor
suspendido o deshabilitado no aporta herramientas al agente y se comprueba de
nuevo antes de cada ejecución. Cambiar la URL o la autenticación invalida las
tools hasta el siguiente descubrimiento.

La API de descubrimiento es `POST /api/app/mcp-servers/:serverName/tools/sync`.
`GET /api/app/mcp-servers/:serverName/tools` consulta las tools importadas.
El cliente del backend utiliza `%Net.HttpRequest`, negocia la sesión MCP y
admite respuestas JSON o SSE y catálogos paginados. HTTPS utiliza certificados
verificados con `APP.MCP.Client` y el almacén de CA del contenedor. Las llamadas
remotas se registran a través del ToolManager y las policies del agente.

Los registros son datos persistentes del IRIS principal y no se crean desde
Docker Compose ni se incorporan automáticamente durante el bootstrap.

## Productos y cotizaciones diarias

`External.Demo.Price` es la única clase persistente de datos de la demostración
MCP. Cada registro contiene `Name`, `Day`, `Price` y `Currency`, sin relaciones
con otras clases. No hay réplica de `App.Demo.Inventory`, SKU ni stock en esta
instancia. El inventario y los envíos viven en el servidor independiente `iris-demo`.

La clase tiene un índice único por nombre y día y el mismo índice de nombres
que `App.Demo.Inventory`:

```objectscript
Index NameSearchIndex On (Name) As %iFind.Index.Basic(
    INDEXOPTION = 1, LANGUAGE = "en", LOWER = 1);
```

Las dos consultas usan explícitamente
`%ID %FIND search_index(NameSearchIndex, ?, 1, 'en')`, con parámetros SQL enlazados
y sin joins. Es una búsqueda por palabras en inglés, no por subcadenas.

- `mcp_demo_SearchInventory(name)` devuelve los nombres distintos de productos
  con cotizaciones que coinciden con la búsqueda, sin repetirlos por fecha.
- `mcp_demo_GetDailyPrices(name, day)` devuelve las cotizaciones de los productos
  coincidentes para una fecha `YYYY-MM-DD`. La respuesta contiene `name`, `day`,
  `count` y `prices`; cada precio incluye `id`, `name`, `day`, `price` y `currency`.
  No se truncan los resultados. Si no hay coincidencias devuelve `prices: []` y
  `count: 0`. Rechaza nombres vacíos y fechas inválidas.

Ejemplo de argumentos para consultar las dos variedades de café:

```json
{"name":"Coffee","day":"2026-10-14"}
```

Al construir la imagen, `External.Demo.Bootstrap.Seed()` crea cotizaciones
**ficticias en EUR** para 20 nombres de productos y siete días terminando en la
fecha de construcción. La carga conserva los precios existentes. No hay fuente
de precios reales ni generación automática de fechas posteriores. Se pueden
cargar registros directamente en `External_Demo.Price`; ejecutar de nuevo el seed
añade los ejemplos que falten para los últimos siete días.

## Verificación

```powershell
./iris-mcp/tests/smoke.ps1
docker cp ./iris-mcp/tests/InventoryTest.cls ai-orchestrator-iris-mcp:/tmp/InventoryTest.cls
Get-Content -Raw iris-mcp/tests/inventory.script | docker compose exec -T iris-mcp iris session IRIS
Get-Content -Raw iris/tests/mcp-prices.script | docker compose exec -T iris iris session IRIS
Get-Content -Raw iris/tests/mcp-protocol.py | docker compose exec -T iris python3 -
Get-Content -Raw iris/tests/mcp-tools.script | docker compose exec -T iris iris session IRIS
```

La prueba HTTP comprueba que únicamente se publican las dos herramientas de
productos y cotizaciones, ejecuta ambas y valida el rechazo de fechas inválidas.
`InventoryTest.cls` prueba iFind, el filtrado por fecha, productos coincidentes,
validaciones y la idempotencia del seed, revirtiendo los datos de prueba.
`mcp-prices.script` consulta cotizaciones mediante un agente temporal y comprueba
su auditoría, revirtiendo sus datos de prueba.
`iris/tests/mcp-registry.script` comprueba el catálogo en
el namespace `APP`, incluidos estados, duplicados, URLs y referencias a
secretos; revierte sus registros de prueba mediante una transacción.
`mcp-protocol.py` verifica JSON, SSE, paginación, Unicode, autenticación, errores
y cierre de sesiones con un servidor de prueba local. `mcp-tools.script`
ejecuta GetDailyPrices desde un agente, comprueba su auditoría, el bloqueo de llamadas
no asignadas o no disponibles y la conservación de estados al sincronizar;
revierte los datos de prueba. No realiza inferencias de LLM.

## Configurar la publicación en IRIS

La publicación se declara explícitamente mediante `%AI.ToolSet` para incluir solo los métodos deseados. En esta preview, la clase contenedora no descubre métodos únicamente por heredarlos.

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

La clase de servicio enlaza el contrato de herramientas con el endpoint:

```objectscript
Class External.MCP.Service Extends %AI.MCP.Service
{
Parameter SPECIFICATION As STRING = "External.MCP.Tools";
}
```

Después de compilar, registra la aplicación en `%SYS` (ya lo hace `iris.script`):

```objectscript
set properties("Type")=18
set properties("NameSpace")="MCP"
set properties("DispatchClass")="External.MCP.Service"
set properties("Enabled")=1
set properties("AutheEnabled")=32
set sc=##class(Security.Applications).Create("/mcp/demo",.properties)
```

Configura el transporte en `config.toml`; las credenciales proceden del entorno:

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
endpoints = [{ path = "/mcp/demo", username = "@{env:IRIS_MCP_USERNAME}", password = "@{env:IRIS_MCP_PASSWORD}" }]
```

La ruta interna de IRIS y la ruta HTTP `/mcp` son distintas. La cuenta debe tener permisos sobre las clases y datos publicados. Si la aplicación ya existe, actualiza su configuración en el portal en lugar de crearla otra vez.

## Añadir el servidor en AI Orchestrator

1. Abre **Servidores MCP** y pulsa **Registrar servidor**.
2. Usa nombre `iris-mcp-demo`, URL `http://iris-mcp-transport:8080/mcp`, transporte `streamable-http`, autenticación `none`, estado `approved` y habilitado.
3. Guarda y pulsa **Descubrir herramientas**. Abre **Ver herramientas** para revisar nombres y parámetros.
4. En **Agentes**, edita el agente y selecciona las herramientas remotas permitidas. Configura sus policies y autoriza al usuario en **Usuarios IA**.
5. Abre el chat y prueba una consulta con `Coffee`. La auditoría del agente registra las llamadas.

También puedes usar la API autenticada. Cuerpo de `POST /api/app/mcp-servers`:

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

Después ejecuta `POST /api/app/mcp-servers/iris-mcp-demo/tools/sync`. La respuesta incluye las tools importadas; asígnalas mediante la edición del agente o `PUT /api/app/agents/:agentName/tools`. Consulta `GET /api/app/mcp-servers/iris-mcp-demo/tools`.

`authMode: none` corresponde al transporte de esta red Docker de ejemplo: las credenciales anteriores autentican el transporte frente a IRIS. No implica autenticación del cliente MCP. Para un endpoint protegido por un gateway que valide Bearer, configura `authMode: bearer` y `bearerSecret: secret://<referencia>` del Secure Wallet; no pongas el token en JSON ni en Git.
