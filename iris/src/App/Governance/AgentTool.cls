Include %occStatus

/// Dynamic allow-list that determines which governed tools an agent can see.
Class App.Governance.AgentTool Extends %Persistent
{

Property AgentName As %String(MAXLEN = 120) [ Required ];
Property ToolName As %String(MAXLEN = 120) [ Required ];
Property CreatedAt As %TimeStamp;

Index AssignmentIndex On (AgentName, ToolName) [ Unique ];

ClassMethod SetForAgent(agentName As %String, tools As %DynamicArray) As %Status
{
    if '$isobject(tools) return $$$ERROR($$$GeneralError, "tools must be an array")
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Agent WHERE Name = ?", agentName)
    if 'rs.%Next() return $$$ERROR($$$GeneralError, "Agent does not exist: " _ agentName)

    for index = 0:1:(tools.%Size() - 1) {
        set toolName = tools.%Get(index)
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID FROM App_Governance.Tool " _
            "WHERE Name = ? AND Status = 'approved' AND Enabled = 1", toolName)
        if 'rs.%Next() return $$$ERROR($$$GeneralError, "Tool is not approved and enabled: " _ toolName)
        if '##class(App.Governance.Tool).IsAvailable(toolName) return $$$ERROR($$$GeneralError, "Tool or MCP server is not available: " _ toolName)
    }

    tstart
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "DELETE FROM App_Governance.AgentTool WHERE AgentName = ?", agentName)
    if rs.%SQLCODE < 0 { trollback  return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message) }
    for index = 0:1:(tools.%Size() - 1) {
        set item = ..%New()
        set item.AgentName = agentName
        set item.ToolName = tools.%Get(index)
        set item.CreatedAt = $zdatetime($horolog, 3)
        set sc = item.%Save()
        if $$$ISERR(sc) { trollback  return sc }
    }
    tcommit
    return $$$OK
}

ClassMethod ListForAgent(agentName As %String) As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ToolName FROM App_Governance.AgentTool WHERE AgentName = ? ORDER BY ToolName", agentName)
    while rs.%Next() { do output.%Push(rs.%Get("ToolName")) }
    return output
}

ClassMethod IsAllowed(agentName As %String, toolName As %String) As %Boolean
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.AgentTool WHERE AgentName = ? AND ToolName = ?",
        agentName, toolName)
    return rs.%Next()
}

}
