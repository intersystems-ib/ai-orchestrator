Include %occStatus

/// Declarative governed agent. References use logical registry names.
Class App.Governance.Agent Extends (%Persistent, %JSON.Adaptor)
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property ModelName As %String(MAXLEN = 120) [ Required ];
Property SystemPrompt As %String(MAXLEN = "");
Property Temperature As %Numeric(SCALE = 2) [ InitialExpression = 0.2 ];
Property MaxIterations As %Integer(MINVAL = 1, MAXVAL = 100) [ InitialExpression = 10 ];
/// Retained only to preserve the storage layout of upgrades from the former
/// ToolSet-based implementation. It is never read, written, or exposed.
Property ToolSets As %String(MAXLEN = "") [ Internal ];
Property Policies As %String(MAXLEN = "");
Property Status As %String(VALUELIST = ",draft,approved,suspended,retired") [ InitialExpression = "draft" ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property CreatedAt As %TimeStamp;

Index NameIndex On Name [ Unique ];

ClassMethod Create(payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set name = payload.%Get("name", "")
    set modelName = payload.%Get("modelName", "")
    if '##class(App.Governance.ClassUtil).ValidName(name) {
        quit $$$ERROR($$$GeneralError, "name is required and cannot contain commas")
    }
    if modelName = "" quit $$$ERROR($$$GeneralError, "modelName is required")

    set tools = payload.%Get("tools", [])
    set policies = payload.%Get("policies", [])
    set status = payload.%Get("status", "draft")
    set requireApproved = (status = "approved")
    set sc = ..ValidateReferences(modelName, tools, policies, requireApproved)
    if $$$ISERR(sc) quit sc

    tstart
    set item = ..%New()
    set item.Name = name
    set item.DisplayName = payload.%Get("displayName", name)
    set item.ModelName = modelName
    set item.SystemPrompt = payload.%Get("systemPrompt", "")
    set item.Temperature = payload.%Get("temperature", 0.2)
    set item.MaxIterations = payload.%Get("maxIterations", 10)
    set item.Policies = ##class(App.Governance.ClassUtil).ArrayToCSV(policies)
    set item.Status = status
    set item.Enabled = payload.%Get("enabled", 1)
    set item.CreatedAt = $zdatetime($horolog, 3)
    set sc = item.%Save()
    if $$$ISERR(sc) { trollback  quit sc }
    set sc = ##class(App.Governance.AgentTool).SetForAgent(name, tools)
    if $$$ISERR(sc) { trollback  quit sc }
    tcommit
    set result = ..OneJSON(item)
    quit $$$OK
}

ClassMethod Update(name As %String, payload As %DynamicObject,
    Output result As %DynamicObject) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Agent WHERE Name = ?", name)
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Agent does not exist: " _ name)
    set item = ..%OpenId(rs.%Get("ID"))

    set modelName = payload.%Get("modelName", item.ModelName)
    set tools = payload.%Get("tools", ##class(App.Governance.AgentTool).ListForAgent(name))
    set policies = payload.%Get("policies", ##class(App.Governance.ClassUtil).CSVToArray(item.Policies))
    set status = payload.%Get("status", item.Status)
    set requireApproved = (status = "approved")
    set sc = ..ValidateReferences(modelName, tools, policies, requireApproved)
    if $$$ISERR(sc) quit sc

    tstart
    set item.DisplayName = payload.%Get("displayName", item.DisplayName)
    set item.ModelName = modelName
    set item.SystemPrompt = payload.%Get("systemPrompt", item.SystemPrompt)
    set item.Temperature = payload.%Get("temperature", item.Temperature)
    set item.MaxIterations = payload.%Get("maxIterations", item.MaxIterations)
    set item.Policies = ##class(App.Governance.ClassUtil).ArrayToCSV(policies)
    set item.Status = status
    set item.Enabled = payload.%Get("enabled", item.Enabled)
    set sc = item.%Save()
    if $$$ISERR(sc) { trollback  quit sc }
    set sc = ##class(App.Governance.AgentTool).SetForAgent(name, tools)
    if $$$ISERR(sc) { trollback  quit sc }
    tcommit
    set result = ..OneJSON(item)
    quit $$$OK
}

ClassMethod ValidateReferences(modelName As %String, tools As %DynamicArray,
    policies As %DynamicArray, requireApproved As %Boolean = 0) As %Status
{
    set stateClause = $select(requireApproved:" AND Status = 'approved' AND Enabled = 1", 1:"")
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM App_Governance.Model WHERE Name = ?" _ stateClause, modelName)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "The selected model is missing or not available")

    if '$isobject(tools) quit $$$ERROR($$$GeneralError, "tools must be an array")
    for index = 0:1:(tools.%Size() - 1) {
        set logicalName = tools.%Get(index)
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Name FROM App_Governance.Tool WHERE Name = ?" _ stateClause, logicalName)
        if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Tool is missing or not available: " _ logicalName)
    }

    if '$isobject(policies) quit $$$ERROR($$$GeneralError, "policies must be an array")
    kill policyTypes
    for index = 0:1:(policies.%Size() - 1) {
        set logicalName = policies.%Get(index)
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Type FROM App_Governance.Policy WHERE Name = ?" _ stateClause, logicalName)
        if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Policy is missing or not available: " _ logicalName)
        set type = rs.%Get("Type")
        if $data(policyTypes(type)) quit $$$ERROR($$$GeneralError, "Only one policy of each type can be assigned")
        set policyTypes(type) = 1
    }
    quit $$$OK
}

ClassMethod ListJSON(username As %String = "") As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name, DisplayName, ModelName, SystemPrompt, Temperature, MaxIterations, " _
        "Policies, Status, Enabled, CreatedAt FROM App_Governance.Agent ORDER BY Name")
    while rs.%Next() {
        if username '= "", '##class(App.Governance.AgentUser).IsAuthorized(username, rs.%Get("Name")) continue
        do output.%Push({
            "id":(rs.%Get("ID")), "name":(rs.%Get("Name")),
            "displayName":(rs.%Get("DisplayName")), "modelName":(rs.%Get("ModelName")),
            "systemPrompt":(rs.%Get("SystemPrompt")), "temperature":(rs.%Get("Temperature")),
            "maxIterations":(rs.%Get("MaxIterations")),
            "tools":(##class(App.Governance.AgentTool).ListForAgent(rs.%Get("Name"))),
            "policies":(##class(App.Governance.ClassUtil).CSVToArray(rs.%Get("Policies"))),
            "status":(rs.%Get("Status")), "enabled":(rs.%Get("Enabled")),
            "createdAt":(rs.%Get("CreatedAt"))
        })
    }
    quit output
}

ClassMethod OneJSON(item As App.Governance.Agent) As %DynamicObject [ Internal, Private ]
{
    quit {
        "id":(item.%Id()), "name":(item.Name), "displayName":(item.DisplayName),
        "modelName":(item.ModelName), "systemPrompt":(item.SystemPrompt),
        "temperature":(item.Temperature), "maxIterations":(item.MaxIterations),
        "tools":(##class(App.Governance.AgentTool).ListForAgent(item.Name)),
        "policies":(##class(App.Governance.ClassUtil).CSVToArray(item.Policies)),
        "status":(item.Status), "enabled":(item.Enabled), "createdAt":(item.CreatedAt)
    }
}

}
