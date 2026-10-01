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
  <Route Url="/ai-users" Method="GET" Call="ListAIUsers" />
  <Route Url="/ai-users" Method="POST" Call="SetAIUser" />
  <Route Url="/ai-users/:username/agents" Method="PUT" Call="SetAIUserAgents" />
  <Route Url="/chat" Method="POST" Call="Chat" />
  <Route Url="/providers" Method="GET" Call="Providers" />
  <Route Url="/models" Method="GET" Call="ListModels" />
  <Route Url="/models" Method="POST" Call="CreateModel" />
  <Route Url="/models/:modelName" Method="PUT" Call="UpdateModel" />
  <Route Url="/tools" Method="GET" Call="ListTools" />
  <Route Url="/tools/sync" Method="POST" Call="SynchronizeTools" />
  <Route Url="/tools/:toolName" Method="PUT" Call="UpdateTool" />
  <Route Url="/policies" Method="GET" Call="ListPolicies" />
  <Route Url="/policies" Method="POST" Call="CreatePolicy" />
  <Route Url="/agents" Method="GET" Call="ListAgents" />
  <Route Url="/my-agents" Method="GET" Call="ListMyAgents" />
  <Route Url="/agents" Method="POST" Call="CreateAgent" />
  <Route Url="/agents/:agentName" Method="PUT" Call="UpdateAgent" />
  <Route Url="/agents/:agentName/tools" Method="GET" Call="GetAgentTools" />
  <Route Url="/agents/:agentName/tools" Method="PUT" Call="SetAgentTools" />
  <Route Url="/agents/:agentName/catalog" Method="GET" Call="GetAgentCatalog" />
  <Route Url="/agents/:agentName/test" Method="POST" Call="TestAgent" />
  <Route Url="/tools/:toolName/policies" Method="GET" Call="GetToolPolicies" />
  <Route Url="/tools/:toolName/policies" Method="PUT" Call="SetToolPolicies" />
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
    quit $$$OK
}

ClassMethod ListAIUsers() As %Status
{
    do ..WriteJSON(##class(App.Governance.AIUser).ListJSON())
    quit $$$OK
}

ClassMethod SetAIUserAgents(username As %String) As %Status
{
    if $roles '[ "%All" {
        do ..WriteError($$$ERROR($$$GeneralError, "Only IRIS administrators can manage AI users"), 403)
        quit $$$OK
    }
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.AgentUser).SetForUser(
        username, payload.%Get("agents", []))
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  quit $$$OK }
    do ..WriteJSON({
        "username":(username),
        "agents":(##class(App.Governance.AgentUser).ListForUser(username))
    })
    quit $$$OK
}

ClassMethod SetAIUser() As %Status
{
    if $roles '[ "%All" {
        do ..WriteError($$$ERROR($$$GeneralError, "Only IRIS administrators can manage AI users"), 403)
        quit $$$OK
    }
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.AIUser).Set(payload, .result)
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  quit $$$OK }
    do ..WriteJSON(result)
    quit $$$OK
}

ClassMethod Chat() As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.AIHub.Policy.UserAccess).Check(
        $username, payload.%Get("agentName", ""))
    if $$$ISERR(sc) { do ..WriteError(sc, 403)  quit $$$OK }
    set sc = ##class(App.AIHub.ChatService).Send(
        payload.%Get("agentName", ""), payload.%Get("message", ""),
        payload.%Get("conversationId", ""), $username, .result)
    if $$$ISERR(sc) { do ..WriteError(sc, 502)  quit $$$OK }
    do ..WriteJSON(result)
    quit $$$OK
}

ClassMethod Providers() As %Status
{
    do ..WriteJSON(##class(App.Governance.Catalog).Providers())
    quit $$$OK
}

ClassMethod ListModels() As %Status
{
    do ..WriteJSON(##class(App.Governance.Model).ListJSON())
    quit $$$OK
}

ClassMethod CreateModel() As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.Model).Create(payload, .result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        quit $$$OK
    }
    do ..WriteJSON(result, 201)
    quit $$$OK
}

ClassMethod UpdateModel(modelName As %String) As %Status
{
    quit ..UpdateResource("App.Governance.Model", modelName)
}

ClassMethod ListTools() As %Status
{
    do ..WriteJSON(##class(App.Governance.Tool).ListJSON())
    quit $$$OK
}

ClassMethod SynchronizeTools() As %Status
{
    set sc = ##class(App.Governance.Tool).Synchronize(.result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        quit $$$OK
    }
    do ..WriteJSON(result)
    quit $$$OK
}

ClassMethod UpdateTool(toolName As %String) As %Status
{
    quit ..UpdateResource("App.Governance.Tool", toolName)
}

ClassMethod ListPolicies() As %Status
{
    do ..WriteJSON(##class(App.Governance.Policy).ListJSON())
    quit $$$OK
}

ClassMethod CreatePolicy() As %Status
{
    quit ..CreateResource("App.Governance.Policy")
}

ClassMethod ListAgents() As %Status
{
    do ..WriteJSON(##class(App.Governance.Agent).ListJSON())
    quit $$$OK
}

ClassMethod ListMyAgents() As %Status
{
    if '##class(App.Governance.AIUser).IsAuthorized($username) {
        do ..WriteJSON([])
        quit $$$OK
    }
    do ..WriteJSON(##class(App.Governance.Agent).ListJSON($username))
    quit $$$OK
}

ClassMethod CreateAgent() As %Status
{
    quit ..CreateResource("App.Governance.Agent")
}

ClassMethod UpdateAgent(agentName As %String) As %Status
{
    quit ..UpdateResource("App.Governance.Agent", agentName)
}

ClassMethod GetAgentTools(agentName As %String) As %Status
{
    do ..WriteJSON({
        "agent":(agentName),
        "tools":(##class(App.Governance.AgentTool).ListForAgent(agentName))
    })
    quit $$$OK
}

ClassMethod SetAgentTools(agentName As %String) As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.AgentTool).SetForAgent(agentName, payload.%Get("tools", []))
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  quit $$$OK }
    quit ..GetAgentTools(agentName)
}

ClassMethod GetAgentCatalog(agentName As %String) As %Status
{
    set sc = ##class(App.AIHub.AgentFactory).Create(agentName, .agent)
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  quit $$$OK }
    do ..WriteJSON({
        "agent":(agentName),
        "tools":(agent.ToolManager.%Discover())
    })
    quit $$$OK
}

ClassMethod GetToolPolicies(toolName As %String) As %Status
{
    do ..WriteJSON({
        "tool":(toolName),
        "policies":(##class(App.Governance.ToolPolicy).ListForTool(toolName))
    })
    quit $$$OK
}

ClassMethod SetToolPolicies(toolName As %String) As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = ##class(App.Governance.ToolPolicy).SetForTool(toolName, payload.%Get("policies", []))
    if $$$ISERR(sc) { do ..WriteError(sc, 400)  quit $$$OK }
    quit ..GetToolPolicies(toolName)
}

ClassMethod ListAuditEvents() As %Status
{
    do ..WriteJSON(##class(App.Governance.AuditEvent).ListJSON())
    quit $$$OK
}

ClassMethod TestAgent(agentName As %String) As %Status
{
    set payload = {}.%FromJSON(%request.Content)
    set prompt = payload.%Get("prompt", "Reply with exactly: configuration-ok")
    set sc = ##class(App.AIHub.AgentFactory).Create(agentName, .agent)
    if $$$ISOK(sc) {
        try {
            set session = agent.CreateSession()
            set response = agent.Chat(session, prompt)
            set result = {"agent":(agentName), "content":(response.Content)}
        } catch exception {
            set sc = exception.AsStatus()
        }
    }
    if $$$ISERR(sc) {
        do ..WriteError(sc, 502)
        quit $$$OK
    }
    do ..WriteJSON(result)
    quit $$$OK
}

ClassMethod CreateResource(className As %String) As %Status [ Internal, Private ]
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = $classmethod(className, "Create", payload, .result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        quit $$$OK
    }
    do ..WriteJSON(result, 201)
    quit $$$OK
}

ClassMethod UpdateResource(className As %String, name As %String) As %Status [ Internal, Private ]
{
    set payload = {}.%FromJSON(%request.Content)
    set sc = $classmethod(className, "Update", name, payload, .result)
    if $$$ISERR(sc) {
        do ..WriteError(sc, 400)
        quit $$$OK
    }
    do ..WriteJSON(result)
    quit $$$OK
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

