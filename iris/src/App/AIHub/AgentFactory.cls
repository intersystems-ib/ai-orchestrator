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
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "No approved agent is registered with that name")

    set modelName = rs.%Get("ModelName")
    set systemPrompt = rs.%Get("SystemPrompt")
    set temperature = rs.%Get("Temperature")
    set maxIterations = rs.%Get("MaxIterations")
    set policies = rs.%Get("Policies")

    set model = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Provider, ModelId, ApiKey, BaseUrl, OrgId, Version, Region, " _
        "BearerToken, ProjectId, ServiceAccountPath, SiteUrl, SiteName " _
        "FROM App_Governance.Model " _
        "WHERE Name = ? AND Status = 'approved' AND Enabled = 1", modelName)
    if model.%SQLCODE < 0 quit $$$ERROR($$$SQLError, model.%SQLCODE, model.%Message)
    if 'model.%Next() quit $$$ERROR($$$GeneralError, "The agent model is not approved and enabled")

    set details = {"model_provider":(model.%Get("Provider")), "model":(model.%Get("ModelId"))}
    do ..AddDetail(details, "api_key", model.%Get("ApiKey"))
    do ..AddDetail(details, "base_url", model.%Get("BaseUrl"))
    do ..AddDetail(details, "org_id", model.%Get("OrgId"))
    do ..AddDetail(details, "version", model.%Get("Version"))
    do ..AddDetail(details, "region", model.%Get("Region"))
    do ..AddDetail(details, "bearer_token", model.%Get("BearerToken"))
    do ..AddDetail(details, "project_id", model.%Get("ProjectId"))
    do ..AddDetail(details, "service_account_path", model.%Get("ServiceAccountPath"))
    do ..AddDetail(details, "site_url", model.%Get("SiteUrl"))
    do ..AddDetail(details, "site_name", model.%Get("SiteName"))
    set secretResolver = ##class(%ConfigStore.Configuration).%New()
    set secretResolver.Details = details
    set sc = secretResolver.CopyDetails(.resolvedDetails, 1)
    if $$$ISERR(sc) quit sc
    set details = resolvedDetails

    set provider = ##class(%AI.Provider).Create(model.%Get("Provider"), details)
    if '$ISOBJECT(provider) quit $$$ERROR($$$GeneralError, "AI Hub could not create the provider")
    if 'provider.ValidateConfig() quit $$$ERROR($$$GeneralError, "The provider configuration is invalid")

    set agent = ##class(%AI.Agent).%New(provider)
    set agent.Model = model.%Get("ModelId")
    set agent.SystemPrompt = systemPrompt
    set agent.Temperature = temperature
    set agent.MaxIterations = maxIterations

    set sc = agent.%Init()
    if $$$ISERR(sc) quit sc
    do ##class(App.AIHub.RuntimeContext).SetAgent(agentName)
    set sc = ..AttachTools(agent, agentName)
    if $$$ISERR(sc) quit sc
    set sc = ..AttachPolicies(agent, policies)
    if $$$ISERR(sc) quit sc
    do agent.ToolManager.SetAuthPolicy(##class(App.AIHub.Policy.UserAccess).%New())
    do agent.ToolManager.SetAuditPolicy(##class(App.AIHub.Policy.DynamicAudit).%New())
    quit $$$OK
}

ClassMethod AddDetail(details As %DynamicObject, key As %String,
    value As %String) [ Internal, Private ]
{
    if value '= "" do details.%Set(key, value)
}

ClassMethod AttachTools(agent As %AI.Agent, agentName As %String) As %Status [ Internal, Private ]
{
    set sc = $$$OK
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT t.Name, t.ClassName, t.MethodName FROM App_Governance.AgentTool assignment " _
        "JOIN App_Governance.Tool t ON t.Name = assignment.ToolName " _
        "WHERE assignment.AgentName = ? AND t.Status = 'approved' AND t.Enabled = 1 " _
        "ORDER BY t.Name", agentName)
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    while rs.%Next() {
        set sc = ##class(App.AIHub.Tool.SelectedMethod).Create(
            rs.%Get("ClassName"), rs.%Get("MethodName"), .tool)
        if $$$ISERR(sc) quit
        set sc = agent.ToolManager.AddTool(tool)
        if $$$ISERR(sc) quit
    }
    quit sc
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
        // Audit policies are selected dynamically per tool by DynamicAudit.
        if type = "discovery" do agent.ToolManager.SetDiscoveryPolicy(policy)
    }
    quit $$$OK
}

}

