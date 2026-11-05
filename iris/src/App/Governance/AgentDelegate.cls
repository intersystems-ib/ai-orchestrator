Include %occStatus

/// Explicit allow-list of registered agents that an agent may invoke.
Class App.Governance.AgentDelegate Extends %Persistent
{

Property AgentName As %String(MAXLEN = 120) [ Required ];
Property DelegateName As %String(MAXLEN = 120) [ Required ];
Index AssignmentIndex On (AgentName, DelegateName) [ Unique ];

ClassMethod Validate(agentName As %String, delegates As %DynamicArray) As %Status
{
    if '$isobject(delegates) return $$$ERROR($$$GeneralError, "delegates must be an array")
    if 'delegates.%IsA("%DynamicArray") return $$$ERROR($$$GeneralError, "delegates must be an array")
    kill seen
    for index = 0:1:(delegates.%Size() - 1) {
        if delegates.%GetTypeOf(index) '= "string" return $$$ERROR($$$GeneralError, "Each delegate must be an agent name")
        set name = delegates.%Get(index)
        set key = $zconvert(name, "U")
        if key = $zconvert(agentName, "U") return $$$ERROR($$$GeneralError, "An agent cannot delegate to itself")
        if $data(seen(key)) return $$$ERROR($$$GeneralError, "Duplicate delegate: " _ name)
        set seen(key) = 1
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Name FROM App_Governance.Agent WHERE Name = ? AND Status = 'approved' AND Enabled = 1", name)
        if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
        if 'rs.%Next() return $$$ERROR($$$GeneralError, "Delegate is not approved and enabled: " _ name)
        kill visited
        if ..Reaches(name, agentName, .visited) return $$$ERROR($$$GeneralError, "Agent delegation cannot contain a cycle")
    }
    return $$$OK
}

ClassMethod Reaches(current As %String, target As %String, ByRef visited) As %Boolean [ Private ]
{
    set key = $zconvert(current, "U")
    if key = $zconvert(target, "U") return 1
    if $data(visited(key)) return 0
    set visited(key) = 1
    set names = ..ListForAgent(current)
    for index = 0:1:(names.%Size() - 1) {
        if ..Reaches(names.%Get(index), target, .visited) return 1
    }
    return 0
}

ClassMethod SetForAgent(agentName As %String, delegates As %DynamicArray) As %Status
{
    set parent = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM App_Governance.Agent WHERE Name = ?", agentName)
    if 'parent.%Next() return $$$ERROR($$$GeneralError, "Agent does not exist: " _ agentName)
    set sc = ..Validate(agentName, delegates)
    if $$$ISERR(sc) return sc
    tstart
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "DELETE FROM App_Governance.AgentDelegate WHERE AgentName = ?", agentName)
    if rs.%SQLCODE < 0 { trollback  return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message) }
    for index = 0:1:(delegates.%Size() - 1) {
        set item = ..%New()
        set item.AgentName = agentName, item.DelegateName = delegates.%Get(index)
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
        "SELECT DelegateName FROM App_Governance.AgentDelegate WHERE AgentName = ? ORDER BY DelegateName", agentName)
    while rs.%Next() { do output.%Push(rs.%Get("DelegateName")) }
    return output
}

ClassMethod IsAllowed(agentName As %String, delegateName As %String) As %Boolean
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT a.ID FROM App_Governance.AgentDelegate d JOIN App_Governance.Agent a ON a.Name = d.DelegateName " _
        "WHERE d.AgentName = ? AND d.DelegateName = ? AND a.Status = 'approved' AND a.Enabled = 1",
        agentName, delegateName)
    return rs.%Next()
}

}
