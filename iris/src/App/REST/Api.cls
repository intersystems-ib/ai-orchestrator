Class App.REST.Api Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;
Parameter CHARSET = "utf-8";
Parameter CONTENTTYPE = "application/json";
Parameter CONVERTINPUTSTREAM = 1;

XData UrlMap
{
<Routes>
  <Route Url="/health" Method="GET" Call="Health" />
  <Route Url="/mcp-servers" Method="GET" Call="ListMCPServers" />
  <Route Url="/mcp-servers" Method="POST" Call="CreateMCPServer" />
  <Route Url="/mcp-servers/:serverName" Method="DELETE" Call="DeleteMCPServer" />
  <Route Url="/mcp-servers/:serverName" Method="PUT" Call="UpdateMCPServer" />
  <Route Url="/mcp-servers/:serverName/tools" Method="GET" Call="ListMCPTools" />
  <Route Url="/mcp-servers/:serverName/tools/sync" Method="POST" Call="SynchronizeMCPTools" />
  <Route Url="/ai-users" Method="GET" Call="ListAIUsers" />
  <Route Url="/ai-users" Method="POST" Call="SetAIUser" />
  <Route Url="/ai-users/:username/agents" Method="PUT" Call="SetAIUserAgents" />
  <Route Url="/chat" Method="POST" Call="Chat" />
  <Route Url="/providers" Method="GET" Call="Providers" />
  <Route Url="/models" Method="GET" Call="ListModels" />
  <Route Url="/models" Method="POST" Call="CreateModel" />
  <Route Url="/models/:modelName" Method="DELETE" Call="DeleteModel" />
  <Route Url="/models/:modelName" Method="PUT" Call="UpdateModel" />
  <Route Url="/tools" Method="GET" Call="ListTools" />
  <Route Url="/tools/sync" Method="POST" Call="SynchronizeTools" />
  <Route Url="/tools/:toolName" Method="PUT" Call="UpdateTool" />
  <Route Url="/policies" Method="GET" Call="ListPolicies" />
  <Route Url="/policies" Method="POST" Call="CreatePolicy" />
  <Route Url="/agents" Method="GET" Call="ListAgents" />
  <Route Url="/my-agents" Method="GET" Call="ListMyAgents" />
  <Route Url="/agents" Method="POST" Call="CreateAgent" />
  <Route Url="/agents/:agentName" Method="DELETE" Call="DeleteAgent" />
  <Route Url="/agents/:agentName" Method="PUT" Call="UpdateAgent" />
  <Route Url="/agents/:agentName/tools" Method="GET" Call="GetAgentTools" />
  <Route Url="/agents/:agentName/tools" Method="PUT" Call="SetAgentTools" />
  <Route Url="/agents/:agentName/catalog" Method="GET" Call="GetAgentCatalog" />
  <Route Url="/agents/:agentName/test" Method="POST" Call="TestAgent" />
  <Route Url="/audit-events" Method="GET" Call="ListAuditEvents" />
</Routes>
}

ClassMethod Health() As %Status
{
    set body = {
        "status":"ok",
        "service":"iris-ai-governance",
        "platform":"InterSystems IRIS AI Hub"
    }
    do ..WriteJSON(body)
    return $$$OK
}

ClassMethod ListMCPServers() As %Status
{
    do ..WriteJSON(##class(App.Governance.MCPServer).ListJSON())
    return $$$OK
}

ClassMethod CreateMCPServer() As %Status
{
    return ..CreateResource("App.Governance.MCPServer")
}

ClassMethod UpdateMCPServer(serverName As %String) As %Status
{
    return ..UpdateResource("App.Governance.MCPServer", serverName)
}

ClassMethod ListMCPTools(serverName As %String) As %Status
{
    do ..WriteJSON(##class(App.Governance.Tool).ListJSON(serverName))
    return $$$OK
}

ClassMethod SynchronizeMCPTools(serverName As %String) As %Status
{
    set sc = ##class(App.AIHub.MCP.Catalog).Synchronize(serverName, .result)
    if $$$ISERR(sc) { do ..WriteError(sc, 400) return $$$OK }
    do ..WriteJSON(result)
    return $$$OK
}

ClassMethod ListAIUsers() As %Status
{
    do ..WriteJSON(##class(App.Governance.AIUser).ListJSON())
    return $$$OK
}

ClassMethod SetAIUserAgents(username As %String) As %Status
{
    if $roles '[ "%All" {
        do ..WriteError($$$ERROR($$$GeneralError, "Only IRIS administrators can manage AI users"), 403)
        return $$$OK
    }
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.AgentUser).SetForUser(
        username, payload.%Get("agents", []))
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  return $$$OK }
    do ..WriteJSON({
        "username":(username),
        "agents":(##class(App.Governance.AgentUser).ListForUser(username))
    })
    return $$$OK
}

ClassMethod SetAIUser() As %Status
{
    if $roles '[ "%All" {
        do ..WriteError($$$ERROR($$$GeneralError, "Only IRIS administrators can manage AI users"), 403)
        return $$$OK
    }
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.AIUser).Set(payload, .result)
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  return $$$OK }
    do ..WriteJSON(result)
    return $$$OK
}

ClassMethod Chat() As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Interop.Gateway).Send(
        payload.%Get("agentName", ""), payload.%Get("message", ""),
        payload.%Get("conversationId", ""), $username, "chat", .result, .httpStatus)
    if $$$ISERR(sc) { do ..WriteError(sc, httpStatus)  return $$$OK }
    do ..WriteJSON(result)
    return $$$OK
}

ClassMethod Providers() As %Status
{
    do ..WriteJSON(##class(App.Governance.Catalog).Providers())
    return $$$OK
}

ClassMethod ListModels() As %Status
{
    do ..WriteJSON(##class(App.Governance.Model).ListJSON())
    return $$$OK
}

ClassMethod CreateModel() As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.Model).Create(payload, .result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        return $$$OK
    }
    do ..WriteJSON(result, 201)
    return $$$OK
}

ClassMethod UpdateModel(modelName As %String) As %Status
{
    return ..UpdateResource("App.Governance.Model", modelName)
}

ClassMethod ListTools() As %Status
{
    do ..WriteJSON(##class(App.Governance.Tool).ListJSON())
    return $$$OK
}

ClassMethod SynchronizeTools() As %Status
{
    set sc = ##class(App.Governance.Tool).Synchronize(.result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        return $$$OK
    }
    do ..WriteJSON(result)
    return $$$OK
}

ClassMethod UpdateTool(toolName As %String) As %Status
{
    return ..UpdateResource("App.Governance.Tool", toolName)
}

ClassMethod ListPolicies() As %Status
{
    do ..WriteJSON(##class(App.Governance.Policy).ListJSON())
    return $$$OK
}

ClassMethod CreatePolicy() As %Status
{
    return ..CreateResource("App.Governance.Policy")
}

ClassMethod ListAgents() As %Status
{
    do ..WriteJSON(##class(App.Governance.Agent).ListJSON())
    return $$$OK
}

ClassMethod ListMyAgents() As %Status
{
    if '##class(App.Governance.AIUser).IsAuthorized($username) {
        do ..WriteJSON([])
        return $$$OK
    }
    do ..WriteJSON(##class(App.Governance.Agent).ListJSON($username))
    return $$$OK
}

ClassMethod CreateAgent() As %Status
{
    return ..CreateResource("App.Governance.Agent")
}

ClassMethod UpdateAgent(agentName As %String) As %Status
{
    return ..UpdateResource("App.Governance.Agent", agentName)
}

ClassMethod GetAgentTools(agentName As %String) As %Status
{
    do ..WriteJSON({
        "agent":(agentName),
        "tools":(##class(App.Governance.AgentTool).ListForAgent(agentName))
    })
    return $$$OK
}

ClassMethod SetAgentTools(agentName As %String) As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.AgentTool).SetForAgent(agentName, payload.%Get("tools", []))
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  return $$$OK }
    return ..GetAgentTools(agentName)
}

ClassMethod GetAgentCatalog(agentName As %String) As %Status
{
    set sc = ##class(App.AIHub.AgentFactory).Create(agentName, .agent)
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  return $$$OK }
    do ..WriteJSON({
        "agent":(agentName),
        "tools":(agent.ToolManager.%Discover())
    })
    return $$$OK
}

ClassMethod ListAuditEvents() As %Status
{
    do ..WriteJSON(##class(App.Governance.AuditEvent).ListJSON())
    return $$$OK
}

ClassMethod TestAgent(agentName As %String) As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set prompt = payload.%Get("prompt", "Reply with exactly: configuration-ok")
    set sc = ##class(App.Interop.Gateway).Send(
        agentName, prompt, "", $username, "test", .chatResult, .httpStatus)
    if $$$ISERR(sc) {
        do ..WriteError(sc, httpStatus)
        return $$$OK
    }
    set result = {"agent":(agentName), "content":(chatResult.content),
        "requestId":(chatResult.requestId)}
    do ..WriteJSON(result)
    return $$$OK
}

ClassMethod CreateResource(className As %String) As %Status [ Internal, Private ]
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = $classmethod(className, "Create", payload, .result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        return $$$OK
    }
    do ..WriteJSON(result, 201)
    return $$$OK
}

ClassMethod UpdateResource(className As %String, name As %String) As %Status [ Internal, Private ]
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = $classmethod(className, "Update", name, payload, .result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        return $$$OK
    }
    do ..WriteJSON(result)
    return $$$OK
}

ClassMethod DeleteModel(modelName As %String) As %Status
{
    return ..DeleteResource("model", modelName)
}

ClassMethod DeleteAgent(agentName As %String) As %Status
{
    return ..DeleteResource("agent", agentName)
}

ClassMethod DeleteMCPServer(serverName As %String) As %Status
{
    return ..DeleteResource("mcp-server", serverName)
}

ClassMethod DeleteResource(kind As %String, name As %String) As %Status [ Private ]
{
    set sc=##class(App.Governance.Deletion).Execute(kind,name,.result,.httpStatus)
    if $$$ISERR(sc) {do ..WriteError(sc,httpStatus) return $$$OK}
    do ..WriteJSON(result)
    return $$$OK
}

ClassMethod WriteJSON(body As %DynamicAbstractObject, status As %Integer = 200)
{
    set %response.Status = status
    set %response.ContentType = "application/json"
    set %response.CharSet = "utf-8"
    write body.%ToJSON()
}

ClassMethod WriteError(sc As %Status, status As %Integer = 400)
{
    set body = {"error":($SYSTEM.Status.GetErrorText(sc))}
    do ..WriteJSON(body, status)
}

}

