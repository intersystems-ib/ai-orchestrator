Include %occStatus

/// Native HTTP transport, safe to call from AI Hub's ObjectScript callbacks.
Class App.AIHub.MCP.Connection Extends %RegisteredObject
{

Property Endpoint As %String;
Property Token As %String [ Private ];
Property SessionId As %String [ Private ];
Property Protocol As %String [ Private ];
Property Counter As %Integer [ InitialExpression = 0, Private ];

Method Open(endpoint As %String, token As %String = "") As %Status
{
    set ..Endpoint = endpoint, ..Token = token
    set sc = ..Call("initialize", {"protocolVersion":"2025-03-26", "capabilities":{},
        "clientInfo":{"name":"AI Orchestrator", "version":"0.1.0"}}, .result)
    if $$$ISERR(sc) quit sc
    set ..Protocol = result.%Get("protocolVersion", "")
    if '$listfind($listbuild("2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"), ..Protocol) {
        quit $$$ERROR($$$GeneralError, "Unsupported MCP protocol version")
    }
    quit ..Call("notifications/initialized", {}, .ignored, 1)
}

Method Call(method As %String, parameters As %DynamicObject,
    Output result As %DynamicObject, notification As %Boolean = 0) As %Status
{
    set result = ""
    set ..Counter = ..Counter + 1
    set message = {"jsonrpc":"2.0", "method":(method), "params":(parameters)}
    if 'notification do message.%Set("id", ..Counter)
    set request = ..Request()
    do request.EntityBody.Write($zconvert(message.%ToJSON(), "O", "UTF8"))
    set sc = request.Post(..Endpoint)
    if $$$ISERR(sc) quit $$$ERROR($$$GeneralError, "MCP connection failed")
    set response = request.HttpResponse
    if '$isobject(response) quit $$$ERROR($$$GeneralError, "MCP server returned no HTTP response")
    if response.StatusCode < 200 || (response.StatusCode >= 300) quit $$$ERROR($$$GeneralError, "MCP HTTP " _ response.StatusCode)
    set session = response.GetHeader("Mcp-Session-Id")
    if session '= "" set ..SessionId = session
    if notification quit $$$OK
    set maximum = 2097152
    if response.Data.Size > maximum quit $$$ERROR($$$GeneralError, "MCP response exceeds the size limit")
    set raw = response.Data.Read(maximum)
    set contentHeader = $zconvert(response.GetHeader("Content-Type"), "L")
    // IRIS decodes JSON as UTF-8, but SSE defaults to Latin-1 without charset.
    if ((contentHeader [ "text/event-stream") && (contentHeader '[ "charset=")) || ('response.Data.%IsA("%Stream.GlobalCharacter") && 'response.Data.%IsA("%Stream.FileCharacter")) {
        set raw = $zconvert(raw, "I", "UTF8")
    }
    set contentType = $zstrip($piece(contentHeader, ";", 1), "<>W")
    if contentType = "application/json" {
        set sc = ..ParseResult(raw, .result)
        if $$$ISERR(sc) quit sc
        if '$isobject(result) quit $$$ERROR($$$GeneralError, "MCP server returned no matching response")
        quit $$$OK
    }
    if contentType '= "text/event-stream" quit $$$ERROR($$$GeneralError, "Unsupported MCP response content type")
    set data = ""
    for lineNumber = 1:1:$length(raw, $char(10)) {
        set line = $translate($piece(raw, $char(10), lineNumber), $char(13), "")
        if line = "" {
            if data '= "" {
                set sc = ..ParseResult(data, .result)
                if $$$ISERR(sc) quit
                if $isobject(result) quit
            }
            set data = ""
        } elseif $extract(line, 1, 5) = "data:" {
            set part = $extract(line, 6, *)
            if $extract(part) = " " set part = $extract(part, 2, *)
            set data = data _ $select(data="":"", 1:$char(10)) _ part
        }
    }
    if $$$ISERR(sc) quit sc
    if '$isobject(result) quit $$$ERROR($$$GeneralError, "MCP server returned no matching response")
    quit $$$OK
}

Method ParseResult(raw As %String, Output result As %DynamicObject) As %Status [ Private ]
{
    set result = ""
    set sc = $$$OK
    try {
        set message = {}.%FromJSON(raw)
        if 'message.%IsA("%DynamicObject") throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "Invalid MCP response"))
        if message.%Get("jsonrpc") '= "2.0" throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "Invalid MCP JSON-RPC response"))
        if message.%Get("id", "") = ..Counter {
            if message.%IsDefined("error") {
                throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "MCP error: " _ message.%Get("error").%Get("message", "request rejected")))
            }
            set result = message.%Get("result")
            if '$isobject(result) throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "Invalid MCP result"))
            if 'result.%IsA("%DynamicObject") throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "Invalid MCP result object"))
        } elseif message.%IsDefined("method"), message.%IsDefined("id") {
            throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "MCP server requested an unsupported client capability"))
        }
    } catch exception {
        set sc = exception.AsStatus()
    }
    quit sc
}

Method ListTools(Output result As %DynamicObject) As %Status
{
    set tools = [], parameters = {}, totalSize = 0, complete = 0
    kill cursors, names
    set sc = $$$OK
    for page = 1:1:100 {
        set sc = ..Call("tools/list", parameters, .response)
        if $$$ISERR(sc) quit
        set batch = response.%Get("tools")
        if '$isobject(batch) { set sc = $$$ERROR($$$GeneralError, "Invalid MCP tools catalog") quit }
        if 'batch.%IsA("%DynamicArray") { set sc = $$$ERROR($$$GeneralError, "Invalid MCP tools array") quit }
        set totalSize = totalSize + $length(batch.%ToJSON())
        if totalSize > 2097152 { set sc = $$$ERROR($$$GeneralError, "MCP catalog exceeds the size limit") quit }
        for index = 0:1:(batch.%Size() - 1) {
            set tool = batch.%Get(index)
            if '$isobject(tool) { set sc = $$$ERROR($$$GeneralError, "Invalid MCP tool descriptor") quit }
            if 'tool.%IsA("%DynamicObject") { set sc = $$$ERROR($$$GeneralError, "Invalid MCP tool object") quit }
            set name = tool.%Get("name", "")
            if (name = "") || (tool.%GetTypeOf("name") '= "string") { set sc = $$$ERROR($$$GeneralError, "Invalid MCP tool name") quit }
            if $data(names(name)) { set sc = $$$ERROR($$$GeneralError, "Duplicate MCP tool name") quit }
            set schema = tool.%Get("inputSchema")
            if '$isobject(schema) { set sc = $$$ERROR($$$GeneralError, "MCP tool has no input schema") quit }
            if 'schema.%IsA("%DynamicObject") { set sc = $$$ERROR($$$GeneralError, "MCP input schema must be an object") quit }
            if schema.%Get("type") '= "object" { set sc = $$$ERROR($$$GeneralError, "MCP tool input schema must have object type") quit }
            set names(name) = 1
            do tools.%Push(tool)
        }
        if $$$ISERR(sc) quit
        if tools.%Size() > 10000 { set sc = $$$ERROR($$$GeneralError, "MCP catalog exceeds the tool limit") quit }
        set cursor = response.%Get("nextCursor", "")
        if cursor = "" { set complete = 1 quit }
        if response.%GetTypeOf("nextCursor") '= "string" { set sc = $$$ERROR($$$GeneralError, "Invalid MCP pagination cursor") quit }
        if $data(cursors(cursor)) { set sc = $$$ERROR($$$GeneralError, "MCP server repeated a pagination cursor") quit }
        set cursors(cursor) = 1
        set parameters = {"cursor":(cursor)}
    }
    if $$$ISERR(sc) quit sc
    if 'complete quit $$$ERROR($$$GeneralError, "MCP catalog exceeds the page limit")
    set result = {"tools":(tools)}
    quit $$$OK
}

Method Request() As %Net.HttpRequest [ Private ]
{
    set request = ##class(%Net.HttpRequest).%New()
    set request.Timeout = 30, request.WriteTimeout = 30, request.FollowRedirect = 0
    set request.ContentType = "application/json", request.WriteRawMode = 1
    set request.SSLConfiguration = "APP.MCP.Client", request.SSLCheckServerIdentity = 1
    do request.SetHeader("Accept", "application/json, text/event-stream")
    if ..Token '= "" do request.SetHeader("Authorization", "Bearer " _ ..Token)
    if ..SessionId '= "" do request.SetHeader("Mcp-Session-Id", ..SessionId)
    if ..Protocol '= "" do request.SetHeader("MCP-Protocol-Version", ..Protocol)
    quit request
}

Method Close()
{
    if ..SessionId = "" quit
    try {
        set request = ..Request()
        set request.Timeout = 5
        set sc = request.Delete(..Endpoint)
    } catch exception {
        // Session cleanup must not replace the result of the tool call.
    }
    set ..Token = "", ..SessionId = ""
}

ClassMethod ConfigureTLS() As %Status
{
    new $namespace
    set $namespace = "%SYS"
    if ##class(Security.SSLConfigs).Exists("APP.MCP.Client") quit $$$OK
    set properties("Enabled") = 1, properties("Type") = 0
    set properties("VerifyPeer") = 2
    set properties("CAFile") = "/etc/ssl/certs/ca-certificates.crt"
    quit ##class(Security.SSLConfigs).Create("APP.MCP.Client", .properties)
}

}
