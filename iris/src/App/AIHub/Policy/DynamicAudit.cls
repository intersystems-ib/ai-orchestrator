Include %occStatus

/// Composes the audit policies assigned to the executing agent.
Class App.AIHub.Policy.DynamicAudit Extends %AI.Policy.Audit
{

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject,
    result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
    set agentName = ##class(App.AIHub.RuntimeContext).GetAgent()
    kill applied
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Policies FROM App_Governance.Agent WHERE Name = ?", agentName)
    if rs.%Next() {
        set names = rs.%Get("Policies")
        for index = 1:1:$length(names, ",") {
            set policyName = $piece(names, ",", index)
            if policyName = "" continue
            set policyKey = $zconvert(policyName, "U")
            if $data(applied(policyKey)) continue
            set applied(policyKey) = 1
            set policy = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT ClassName FROM App_Governance.Policy WHERE Name = ? " _
                "AND Type = 'audit' AND Status = 'approved' AND Enabled = 1", policyName)
            if policy.%Next() do ..Invoke(policy.%Get("ClassName"), call, metadata, result, duration, status)
        }
    }
    return $$$OK
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
