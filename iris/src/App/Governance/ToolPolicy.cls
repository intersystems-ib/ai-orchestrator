Include %occStatus

/// Dynamic mapping between a governed tool and its audit policies.
Class App.Governance.ToolPolicy Extends %Persistent
{

Property ToolName As %String(MAXLEN = 120) [ Required ];
Property PolicyName As %String(MAXLEN = 120) [ Required ];
Property CreatedAt As %TimeStamp;

Index AssignmentIndex On (ToolName, PolicyName) [ Unique ];

ClassMethod SetForTool(toolName As %String, policies As %DynamicArray) As %Status
{
    if '$isobject(policies) quit $$$ERROR($$$GeneralError, "policies must be an array")
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Tool WHERE Name = ?", toolName)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Tool does not exist: " _ toolName)

    for index = 0:1:(policies.%Size() - 1) {
        set policyName = policies.%Get(index)
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID FROM App_Governance.Policy " _
            "WHERE Name = ? AND Type = 'audit' AND Status = 'approved' AND Enabled = 1", policyName)
        if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Audit policy is not approved and enabled: " _ policyName)
    }

    tstart
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "DELETE FROM App_Governance.ToolPolicy WHERE ToolName = ?", toolName)
    if rs.%SQLCODE < 0 { trollback  quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message) }
    for index = 0:1:(policies.%Size() - 1) {
        set item = ..%New()
        set item.ToolName = toolName
        set item.PolicyName = policies.%Get(index)
        set item.CreatedAt = $zdatetime($horolog, 3)
        set sc = item.%Save()
        if $$$ISERR(sc) { trollback  quit sc }
    }
    tcommit
    quit $$$OK
}

ClassMethod ListForTool(toolName As %String) As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT PolicyName FROM App_Governance.ToolPolicy WHERE ToolName = ? ORDER BY PolicyName", toolName)
    while rs.%Next() { do output.%Push(rs.%Get("PolicyName")) }
    quit output
}

}
