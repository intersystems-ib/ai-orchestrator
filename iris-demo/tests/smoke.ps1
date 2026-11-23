param([string]$Endpoint = 'http://localhost:8083/mcp')
$ErrorActionPreference = 'Stop'
$headers = @{Accept = 'application/json, text/event-stream'}

function Read-MCPResponse([string]$Content, [int]$ExpectedId) {
    foreach ($line in ($Content -split "`n")) {
        if ($line.StartsWith('data: {')) {
            $message = $line.Substring(6) | ConvertFrom-Json
            if ($message.id -eq $ExpectedId) {
                if ($message.error) { throw ($message.error | ConvertTo-Json -Compress) }
                return $message.result
            }
        }
    }
    throw "No MCP response received for request $ExpectedId"
}

function Send-MCPRequest([int]$RequestId, [string]$Method, [hashtable]$Parameters) {
    $body = @{jsonrpc = '2.0'; id = $RequestId; method = $Method; params = $Parameters} | ConvertTo-Json -Depth 10
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Endpoint -Method POST -ContentType 'application/json' -Headers $headers -Body $body
    if ($RequestId -eq 1) { $headers['Mcp-Session-Id'] = [string]$response.Headers['Mcp-Session-Id'] }
    Read-MCPResponse $response.Content $RequestId
}

try {
    $null = Send-MCPRequest 1 'initialize' @{protocolVersion = '2025-03-26'; capabilities = @{}; clientInfo = @{name = 'business-smoke'; version = '1.0'}}
    $null = Invoke-WebRequest -UseBasicParsing -Uri $Endpoint -Method POST -ContentType 'application/json' -Headers $headers -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    $catalog = Send-MCPRequest 2 'tools/list' @{}
    $expected = @('AddInventoryItem','SearchInventory','SearchShipmentsByDateRange','SearchShipmentsByProduct') | ForEach-Object { 'mcp_business_' + $_ }
    if (@($catalog.tools).Count -ne 4 -or @(Compare-Object ($catalog.tools.name | Sort-Object) ($expected | Sort-Object)).Count) { throw 'Unexpected business catalog' }
    $search = Send-MCPRequest 3 'tools/call' @{name = 'mcp_business_SearchInventory'; arguments = @{name = 'Coffee'}}
    if ($search.isError) { throw 'Inventory search failed' }
    $inventory = (($search.content | Where-Object type -eq 'text').text | ConvertFrom-Json)
    if ($inventory.row_count -ne 2) { throw 'Expected two English coffee product names' }
    # Exercise the write method without changing stock or adding test rows.
    $add = Send-MCPRequest 4 'tools/call' @{name = 'mcp_business_AddInventoryItem'; arguments = @{name = 'Premium ground coffee'; sku = 'IGNORED-FOR-EXISTING-NAME'; quantity = 0}}
    if ($add.isError) { throw 'Stock method failed' }
    $item = (($add.content | Where-Object type -eq 'text').text | ConvertFrom-Json)
    if ($item.created -or -not $item.updated -or $item.quantityAdded -ne 0 -or $item.sku -ne 'INV-001') { throw 'Stock method changed existing product identity' }
    $byProduct = Send-MCPRequest 5 'tools/call' @{name = 'mcp_business_SearchShipmentsByProduct'; arguments = @{productId = $item.id}}
    if ($byProduct.isError) { throw 'Shipment product search failed' }
    $lines = (($byProduct.content | Where-Object type -eq 'text').text | ConvertFrom-Json)
    if ($lines.row_count -lt 1) { throw 'Missing sample shipment lines for INV-001' }
    $byDate = Send-MCPRequest 6 'tools/call' @{name = 'mcp_business_SearchShipmentsByDateRange'; arguments = @{startDate = '2026-09-01'; endDate = '2026-10-31'}}
    if ($byDate.isError) { throw 'Shipment date search failed' }
    $range = (($byDate.content | Where-Object type -eq 'text').text | ConvertFrom-Json)
    if ($range.row_count -lt 1) { throw 'Missing sample shipment date results' }
    'BUSINESS_MCP_SMOKE_OK: four tools, English inventory, stock identity, shipments by product/date'
} finally {
    if ($headers['Mcp-Session-Id']) {
        $null = Invoke-WebRequest -UseBasicParsing -Uri $Endpoint -Method DELETE -Headers $headers
    }
}
