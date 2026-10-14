param([string]$Endpoint = 'http://localhost:8082/mcp')
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
    $initialization = Send-MCPRequest 1 'initialize' @{protocolVersion = '2025-03-26'; capabilities = @{}; clientInfo = @{name = 'project-smoke-test'; version = '1.0'}}
    if (-not $initialization.serverInfo) { throw 'MCP initialization failed' }
    $null = Invoke-WebRequest -UseBasicParsing -Uri $Endpoint -Method POST -ContentType 'application/json' -Headers $headers -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    $catalog = Send-MCPRequest 2 'tools/list' @{}
    $priceTool = $catalog.tools | Where-Object name -eq 'mcp_demo_GetDailyPrices'
    $searchTool = $catalog.tools | Where-Object name -eq 'mcp_demo_SearchInventory'
    if (@($catalog.tools).Count -ne 2 -or -not $priceTool -or -not $searchTool) { throw 'Only the two inventory price tools should be published' }
    if (@($priceTool.inputSchema.required).Count -ne 2) { throw 'Missing quotation parameters' }
    $search = Send-MCPRequest 3 'tools/call' @{name = $searchTool.name; arguments = @{name = "Caf$([char]233)"}}
    if ($search.isError) { throw 'Remote product search failed' }
    $day = Get-Date -Format 'yyyy-MM-dd'
    $price = Send-MCPRequest 5 'tools/call' @{name = $priceTool.name; arguments = @{name = "Caf$([char]233)"; day = $day}}
    if ($price.isError) { throw 'Remote GetDailyPrices failed' }
    $prices = (($price.content | Where-Object type -eq 'text').text | ConvertFrom-Json)
    if ($prices.count -ne 2 -or $prices.prices[0].day -ne $day -or $prices.prices[0].currency -ne 'EUR') { throw 'Incorrect daily quotations' }
    $invalid = Send-MCPRequest 6 'tools/call' @{name = $priceTool.name; arguments = @{name = 'arroz'; day = '2026-02-30'}}
    if (-not $invalid.isError) { throw 'Invalid quotation date was accepted' }
    'MCP OK: only SearchInventory and GetDailyPrices; product search, daily quotations and invalid-date rejection'
} finally {
    if ($headers['Mcp-Session-Id']) {
        $null = Invoke-WebRequest -UseBasicParsing -Uri $Endpoint -Method DELETE -Headers $headers
    }
}
