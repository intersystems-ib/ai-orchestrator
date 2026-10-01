Include %occStatus

/// Dynamic authorization assignments between IRIS users and governed agents.
Class App.Governance.AgentUser Extends %Persistent
{

Property Username As %String(MAXLEN = 128) [ Required ];
Property AgentName As %String(MAXLEN = 120) [ Required ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property AssignedAt As %TimeStamp;
Property AssignedBy As %String(MAXLEN = 128);

Index AssignmentIndex On (Username, AgentName) [ Unique ];
Index UserIndex On Username;
Index AgentIndex On AgentName;

ClassMethod IsAuthorized(username As %String, agentName As %String) As %Boolean
{
    if username = "" || agentName = "" quit 0
    if '##class(App.Governance.AIUser).IsAuthorized(username) quit 0
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT assignment.ID FROM App_Governance.AgentUser assignment " _
        "JOIN App_Governance.Agent agent ON agent.Name = assignment.AgentName " _
        "WHERE assignment.Username = ? AND assignment.AgentName = ? " _
        "AND assignment.Enabled = 1 AND agent.Status = 'approved' AND agent.Enabled = 1",
        username, agentName)
    quit rs.%Next()
}

ClassMethod ListForUser(username As %String) As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT AgentName FROM App_Governance.AgentUser " _
        "WHERE Username = ? AND Enabled = 1 ORDER BY AgentName", username)
    while rs.%Next() { do output.%Push(rs.%Get("AgentName")) }
    quit output
}

ClassMethod SetForUser(username As %String, agents As %DynamicArray) As %Status
{
    if username = "" quit $$$ERROR($$$GeneralError, "username is required")
    if '$isobject(agents) quit $$$ERROR($$$GeneralError, "agents must be an array")
    set user = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.AIUser WHERE Username = ?", username)
    if 'user.%Next() quit $$$ERROR($$$GeneralError, "AI user is not registered: " _ username)

    for index = 0:1:(agents.%Size() - 1) {
        set agentName = agents.%Get(index)
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID FROM App_Governance.Agent WHERE Name = ?", agentName)
        if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Agent does not exist: " _ agentName)
    }

    tstart
    set existing = ##class(%SQL.Statement).%ExecDirect(,
        "DELETE FROM App_Governance.AgentUser WHERE Username = ?", username)
    if existing.%SQLCODE < 0 {
        trollback
        quit $$$ERROR($$$SQLError, existing.%SQLCODE, existing.%Message)
    }
    for index = 0:1:(agents.%Size() - 1) {
        set item = ..%New()
        set item.Username = username
        set item.AgentName = agents.%Get(index)
        set item.Enabled = 1
        set item.AssignedAt = $zdatetime($horolog, 3)
        set item.AssignedBy = $username
        set sc = item.%Save()
        if $$$ISERR(sc) { trollback  quit sc }
    }
    tcommit
    quit $$$OK
}

ClassMethod EnsureAssignment(username As %String, agentName As %String) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.AgentUser WHERE Username = ? AND AgentName = ?",
        username, agentName)
    if rs.%Next() quit $$$OK
    set item = ..%New()
    set item.Username = username
    set item.AgentName = agentName
    set item.Enabled = 1
    set item.AssignedAt = $zdatetime($horolog, 3)
    set item.AssignedBy = $username
    quit item.%Save()
}

}
