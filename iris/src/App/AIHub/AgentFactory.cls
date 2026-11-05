Include %occStatus

/// Materializes an AI Hub agent exclusively from an approved agent definition.
Class App.AIHub.AgentFactory
{

ClassMethod Create(agentName As %String, Output agent As %AI.Agent) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ModelName, SystemPrompt, Temperature, MaxIterations, Policies " _
        "FROM App_Governance.Agent WHERE Name = ? AND Status = 'approved' AND Enabled = 1",
        agentName)
    if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() return $$$ERROR($$$GeneralError, "No approved agent is registered with that name")

    set modelName = rs.%Get("ModelName")
    set systemPrompt = rs.%Get("SystemPrompt")
    set temperature = rs.%Get("Temperature")
    set maxIterations = rs.%Get("MaxIterations")
    set policies = rs.%Get("Policies")

    set model = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Provider, ModelId " _
        "FROM App_Governance.Model " _
        "WHERE Name = ? AND Status = 'approved' AND Enabled = 1", modelName)
    if model.%SQLCODE < 0 return $$$ERROR($$$SQLError, model.%SQLCODE, model.%Message)
    if 'model.%Next() return $$$ERROR($$$GeneralError, "The agent model is not approved and enabled")

    set sc = ##class(App.Governance.Model).GetConnectionDetails(
        model.%Get("ID"), .details, 1)
    if $$$ISERR(sc) return sc
    do details.%Set("model_provider", model.%Get("Provider"))
    do details.%Set("model", model.%Get("ModelId"))

    set provider = ##class(%AI.Provider).Create(model.%Get("Provider"), details)
    if '$ISOBJECT(provider) return $$$ERROR($$$GeneralError, "AI Hub could not create the provider")
    if 'provider.ValidateConfig() return $$$ERROR($$$GeneralError, "The provider configuration is invalid")

    set agent = ##class(%AI.Agent).%New(provider)
    set agent.Model = model.%Get("ModelId")
    set agent.SystemPrompt = systemPrompt
    set agent.Temperature = temperature
    set agent.MaxIterations = maxIterations

    set sc = agent.%Init()
    if $$$ISERR(sc) return sc
    do ##class(App.AIHub.RuntimeContext).SetAgent(agentName)
    set sc = ..AttachTools(agent, agentName)
    if $$$ISERR(sc) return sc
    set sc = ..AttachDelegates(agent, agentName)
    if $$$ISERR(sc) return sc
    set sc = ..AttachPolicies(agent, policies)
    if $$$ISERR(sc) return sc
    do agent.ToolManager.SetAuthPolicy(##class(App.AIHub.Policy.UserAccess).%New())
    do agent.ToolManager.SetAuditPolicy(##class(App.AIHub.Policy.DynamicAudit).%New())
    return $$$OK
}

ClassMethod AttachTools(agent As %AI.Agent, agentName As %String) As %Status [ Internal, Private ]
{
    set sc = $$$OK
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT t.Name, t.ClassName, t.MethodName, t.MCPServerName FROM App_Governance.AgentTool assignment " _
        "JOIN App_Governance.Tool t ON t.Name = assignment.ToolName " _
        "WHERE assignment.AgentName = ? AND t.Status = 'approved' AND t.Enabled = 1 " _
        "ORDER BY t.Name", agentName)
    if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    while rs.%Next() {
        if '##class(App.Governance.Tool).IsAvailable(rs.%Get("Name")) continue
        if rs.%Get("MCPServerName") '= "" {
            set sc = ##class(App.AIHub.Tool.RemoteMCP).Create(rs.%Get("Name"), .tool)
        } else {
            set sc = ##class(App.AIHub.Tool.SelectedMethod).Create(
                rs.%Get("ClassName"), rs.%Get("MethodName"), .tool)
        }
        if $$$ISERR(sc) quit
        set sc = agent.ToolManager.AddTool(tool)
        if $$$ISERR(sc) quit
    }
    return sc
}

ClassMethod AttachDelegates(agent As %AI.Agent, agentName As %String) As %Status [ Internal, Private ]
{
    set names = ##class(App.Governance.AgentDelegate).ListForAgent(agentName)
    for index = 0:1:(names.%Size() - 1) {
        set name = names.%Get(index)
        if '##class(App.Governance.AgentDelegate).IsAllowed(agentName, name) continue
        set sc = ##class(App.AIHub.Tool.DelegateAgent).Create(agentName, name, .tool)
        if $$$ISERR(sc) return sc
        set sc = agent.ToolManager.AddTool(tool)
        if $$$ISERR(sc) return sc
    }
    return $$$OK
}

ClassMethod AttachPolicies(agent As %AI.Agent, names As %String) As %Status [ Internal, Private ]
{
    for index = 1:1:$length(names, ",") {
        set name = $piece(names, ",", index)
        if name = "" continue
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ClassName, Type FROM App_Governance.Policy " _
            "WHERE Name = ? AND Status = 'approved' AND Enabled = 1", name)
        if 'rs.%Next() return $$$ERROR($$$GeneralError, "Policy is not approved and enabled: " _ name)
        set className = rs.%Get("ClassName")
        set policy = $classmethod(className, "%New")
        if '$isobject(policy) return $$$ERROR($$$GeneralError, "Could not instantiate policy: " _ className)
        set type = rs.%Get("Type")
        // UserAccess is mandatory and is the authorization policy in this version.
        // DynamicAudit composes the audit policies selected on this agent.
        if type = "discovery" do agent.ToolManager.SetDiscoveryPolicy(policy)
    }
    return $$$OK
}

}

