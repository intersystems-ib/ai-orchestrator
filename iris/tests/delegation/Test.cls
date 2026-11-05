Include %occStatus

/// Fixtures and assertions for a disposable instance only.
Class App.Test.Delegation Extends %RegisteredObject
{

Property Failures As %Integer [ InitialExpression = 0 ];

Method Check(condition As %Boolean, message As %String)
{
    if 'condition { set ..Failures = ..Failures + 1 write "FAIL ", message, ! }
}

Method Require(sc As %Status)
{
    if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
}

Method Denied(tool As App.AIHub.Tool.DelegateAgent, arguments As %DynamicObject, expected As %String)
{
    set error = ""
    try { set ignored = tool.%Invoke(tool.ToolName, arguments) }
    catch exception { set error = $SYSTEM.Status.GetErrorText(exception.AsStatus()) }
    do ..Check($select(expected="":error'="", 1:$find(error, expected)>0), "denied: " _ expected _ " actual=" _ error)
}

Method Run() As %Integer
{
    try {
        for name = "parent", "specialist" {
            do ..Require(##class(App.Governance.Model).Create({"name":("delegation-" _ name),
                "provider":"nim", "modelId":("delegation-" _ name), "baseUrl":"http://127.0.0.1:18090/v1",
                "apiKey":"not-needed", "status":"approved", "enabled":true}, .ignored))
        }
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT Name FROM App_Governance.Tool WHERE ClassName='App.Demo.InventoryTools' AND MethodName='SearchInventory'")
        do rs.%Next()
        set inventory = rs.%Get("Name")
        do ..Require(##class(App.Governance.Agent).Create({"name":"delegation-specialist", "displayName":"Especialista de inventario",
            "modelName":"delegation-specialist", "systemPrompt":"SPECIALIST_ONLY", "status":"approved",
            "tools":[(inventory)], "policies":["database-audit"]}, .child))
        do ..Require(##class(App.Governance.Agent).Create({"name":"delegation-parent", "displayName":"Coordinador de consultas",
            "modelName":"delegation-parent", "systemPrompt":"PARENT_ONLY", "status":"approved",
            "tools":[(inventory)], "delegates":["delegation-specialist"], "policies":["database-audit"]}, .parent))
        do ..Check(parent.delegates.%Get(0) = "delegation-specialist", "create returns assignments")
        do ..Require(##class(App.Governance.Agent).Update("delegation-parent", {"temperature":0.3}, .parent))
        do ..Check(parent.delegates.%Get(0) = "delegation-specialist", "partial update preserves assignments")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("delegation-parent", {"delegates":["DELEGATION-PARENT"]}, .ignored)), "self delegation")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("delegation-specialist", {"delegates":["delegation-parent"]}, .ignored)), "cycle")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("delegation-parent", {"delegates":["missing"]}, .ignored)), "unknown delegate")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("delegation-parent", {"delegates":["delegation-specialist","DELEGATION-SPECIALIST"]}, .ignored)), "duplicate delegate")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("delegation-parent", {"delegates":{}}, .ignored)), "non-array delegates")
        do ..Check(##class(App.Governance.AgentDelegate).ListForAgent("delegation-parent").%Size() = 1, "failed updates preserve assignments")

        for username = $username, "CSPSystem" {
            do ..Require(##class(App.Governance.AIUser).Set({"username":(username),"enabled":true}, .ignored))
            do ..Require(##class(App.Governance.AgentUser).SetForUser(username, ["delegation-parent","delegation-specialist"]))
        }
        do ##class(App.AIHub.RuntimeContext).SetRequest("delegation-direct", $username)
        do ..Require(##class(App.AIHub.AgentFactory).Create("delegation-parent", .agent))
        do ..Check(agent.ToolManager.%Discover().%Size() = 2, "local tool plus assigned delegate")
        do ..Require(##class(App.AIHub.Tool.DelegateAgent).Create("delegation-parent", "delegation-specialist", .tool))
        do ..Denied(tool, {"prompt":" "}, "cannot be empty")
        do ..Require(##class(App.Governance.AgentUser).SetForUser($username, ["delegation-parent"]))
        do ..Denied(tool, {"prompt":"no permission"}, "not authorized")
        do ..Require(##class(App.Governance.AgentUser).SetForUser($username, ["delegation-parent","delegation-specialist"]))
        do ..Require(##class(App.Governance.Agent).Update("delegation-specialist", {"enabled":false}, .ignored))
        do ..Denied(tool, {"prompt":"disabled"}, "no longer allowed")
        do ..Require(##class(App.Governance.Agent).Update("delegation-specialist", {"enabled":true}, .ignored))

        // Exercise the real nested Chat -> ToolManager -> specialist Chat loop.
        set request = ##class(App.Interop.Message.ChatRequest).%New()
        set request.RequestId = "delegation-end-to-end", request.AgentName = "delegation-parent"
        set request.Username = $username, request.Message = "Consulta al especialista y comprueba el inventario"
        do ..Require(##class(App.Interop.LLMOperation).Execute(request, .response))
        do ..Check(response.Success, "nested inference: " _ response.Error)
        if response.Success {
            set result = {}.%FromJSON(response.ResultJSON)
            do ..Check(result.content = "DELEGATION_OK", "parent consumes specialist answer")
        }
        do ..Check(##class(App.AIHub.RuntimeContext).GetAgent() = "", "root context cleaned")
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS N FROM App_Governance.AuditEvent WHERE RequestId='delegation-end-to-end' AND AgentName='delegation-parent' AND Success=1")
        do rs.%Next()
        do ..Check(rs.%Get("N") = 2, "parent delegate and subsequent local tool audit use parent context")
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS N FROM App_Governance.AuditEvent WHERE RequestId='delegation-end-to-end' AND AgentName='delegation-specialist' AND Success=1")
        do rs.%Next()
        do ..Check(rs.%Get("N") = 1, "specialist has own policy and shared request correlation")
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT COUNT(*) AS N FROM App_Governance.ChatConversation WHERE AgentName IN ('delegation-parent','delegation-specialist')")
        do rs.%Next()
        do ..Check(rs.%Get("N") = 2, "independent parent and specialist sessions")

        do ##class(App.AIHub.RuntimeContext).SetRequest("delegation-negative", $username)
        do ##class(App.AIHub.RuntimeContext).SetAgent("delegation-parent")
        do ..Require(##class(App.Governance.Agent).Update("delegation-specialist", {"modelName":"delegation-parent"}, .ignored))
        // The fixture rejects the wrong model/instructions combination.
        do ..Denied(tool, {"prompt":"provider failure"}, "")
        do ..Check(##class(App.AIHub.RuntimeContext).GetAgent() = "delegation-parent", "context restored after child provider error")
        do ..Require(##class(App.Governance.Agent).Update("delegation-specialist", {"modelName":"delegation-specialist"}, .ignored))
        do ..Require(##class(App.Governance.Agent).Update("delegation-parent", {"delegates":[]}, .ignored))
        do ..Denied(tool, {"prompt":"revoked"}, "no longer allowed")
        do ..Require(##class(App.AIHub.AgentFactory).Create("delegation-parent", .agent))
        do ..Check(agent.ToolManager.%Discover().%Size() = 1, "revoked delegate removed from model catalog")
        do ..Require(##class(App.Governance.Agent).Update("delegation-parent", {"delegates":["delegation-specialist"]}, .ignored))

        do ..Require(##class(App.AIHub.RuntimeContext).EnterDelegate("delegation-specialist"))
        do ..Check($$$ISERR(##class(App.AIHub.RuntimeContext).EnterDelegate("delegation-parent")), "runtime cycle guard")
        do ..Require(##class(App.AIHub.RuntimeContext).EnterDelegate("second-level"))
        do ..Require(##class(App.AIHub.RuntimeContext).EnterDelegate("third-level"))
        do ..Check($$$ISERR(##class(App.AIHub.RuntimeContext).EnterDelegate("fourth-level")), "runtime depth guard")
        do ##class(App.AIHub.RuntimeContext).Clear()
        do ##class(App.AIHub.RuntimeContext).SetAgent("delegation-parent")
        set snapshot = ##class(App.AIHub.RuntimeContext).Snapshot()
        for index = 1:1:16 {
            do ..Require(##class(App.AIHub.RuntimeContext).EnterDelegate("delegation-specialist"))
            do ##class(App.AIHub.RuntimeContext).Restore(snapshot)
        }
        do ..Check($$$ISERR(##class(App.AIHub.RuntimeContext).EnterDelegate("delegation-specialist")), "request-wide delegation budget")
    } catch exception {
        set ..Failures = ..Failures + 1
        write "FAIL exception: ", $SYSTEM.Status.GetErrorText(exception.AsStatus()), !
    }
    do ##class(App.AIHub.RuntimeContext).Clear()
    write "DELEGATION_FAILURES=", ..Failures, !
    return ..Failures
}

}
