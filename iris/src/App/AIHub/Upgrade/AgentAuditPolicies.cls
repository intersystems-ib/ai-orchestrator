Include %occStatus

/// Moves legacy tool audit assignments to the agents that use those tools.
Class App.AIHub.Upgrade.AgentAuditPolicies
{

ClassMethod Run(Output changedAgents As %Integer = 0) As %Status
{
    set changedAgents = 0
    set sc = $$$OK
    tstart
    try {
        set agents = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID, Name FROM App_Governance.Agent ORDER BY ID")
        if agents.%SQLCODE < 0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError, agents.%SQLCODE, agents.%Message))
        while agents.%Next() {
            set item = ##class(App.Governance.Agent).%OpenId(agents.%Get("ID"))
            set names = item.Policies
            set policies = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT DISTINCT p.ID AS PolicyId FROM App_Governance.AgentTool a " _
                "JOIN App_Governance.ToolPolicy t ON t.ToolName = a.ToolName " _
                "JOIN App_Governance.Policy p ON p.Name = t.PolicyName " _
                "WHERE a.AgentName = ? AND p.Type = 'audit' ORDER BY p.ID", agents.%Get("Name"))
            if policies.%SQLCODE < 0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError, policies.%SQLCODE, policies.%Message))
            while policies.%Next() {
                set policyDefinition = ##class(App.Governance.Policy).%OpenId(policies.%Get("PolicyId"))
                set name = policyDefinition.Name
                if $listfind($listfromstring($zconvert(names, "U")), $zconvert(name, "U")) continue
                set names = names _ $select(names="":"", 1:",") _ name
            }
            if names = item.Policies continue
            set item.Policies = names
            set sc = item.%Save()
            if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            set changedAgents = changedAgents + 1
        }
        // Once migrated, legacy assignments must never reapply on later upgrades.
        set deleted = ##class(%SQL.Statement).%ExecDirect(,
            "DELETE FROM App_Governance.ToolPolicy")
        if deleted.%SQLCODE < 0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError, deleted.%SQLCODE, deleted.%Message))
    } catch exception {
        set sc = exception.AsStatus()
    }
    if $$$ISERR(sc) { trollback  quit sc }
    tcommit
    quit $$$OK
}

}
