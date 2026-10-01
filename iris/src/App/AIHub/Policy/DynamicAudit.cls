Include %occStatus

/// Global AI Hub audit policy that dispatches to the policies assigned in IRIS.
Class App.AIHub.Policy.DynamicAudit Extends %AI.Policy.Audit
{

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject,
    result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
    set toolName = call.%Get("name", "")
    set agentName = ##class(App.AIHub.RuntimeContext).GetAgent()
    kill applied

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT p.Name, p.ClassName FROM App_Governance.ToolPolicy tp " _
        "JOIN App_Governance.Policy p ON p.Name = tp.PolicyName " _
        "WHERE tp.ToolName = ? AND p.Type = 'audit' " _
        "AND p.Status = 'approved' AND p.Enabled = 1", toolName)
    while rs.%Next() {
        set policyName = rs.%Get("Name")
        set applied(policyName) = 1
        do ..Invoke(rs.%Get("ClassName"), call, metadata, result, duration, status)
    }

    // Agent-level audit policies remain global and compose with per-tool policies.
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Policies FROM App_Governance.Agent WHERE Name = ?", agentName)
    if rs.%Next() {
        set names = rs.%Get("Policies")
        for index = 1:1:$length(names, ",") {
            set policyName = $piece(names, ",", index)
            if (policyName = "") || $data(applied(policyName)) continue
            set policy = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT ClassName FROM App_Governance.Policy WHERE Name = ? " _
                "AND Type = 'audit' AND Status = 'approved' AND Enabled = 1", policyName)
            if policy.%Next() do ..Invoke(policy.%Get("ClassName"), call, metadata, result, duration, status)
        }
    }
    quit $$$OK
}

ClassMethod Invoke(className As %String, call As %DynamicObject, metadata As %DynamicObject,
    result As %DynamicObject, duration As %Integer, status As %Status) [ Internal, Private ]
{
    try {
        set policy = $classmethod(className, "%New")
        if $isobject(policy) do policy.%LogExecution(call, metadata, result, duration, status)
    } catch exception {
        // An audit sink must not corrupt the tool response. Other configured sinks still run.
    }
}

}
