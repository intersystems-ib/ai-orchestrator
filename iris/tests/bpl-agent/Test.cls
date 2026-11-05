Include %occStatus

/// Run only in a disposable IRIS instance with the local mock LLM fixture.
Class App.Test.AgentOperation Extends %RegisteredObject
{
Property Failures As %Integer [ InitialExpression = 0 ];

Method Check(condition As %Boolean, message As %String)
{
    if 'condition {
        set ..Failures = ..Failures + 1
        write "FAIL ", message, !
    }
}

Method Require(sc As %Status)
{
    if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
}

Method Run() As %Integer
{
    try {
        set operation = ##class(App.Interop.AgentOperation).%New("BPL Unit Test")
        set request = ##class(Ens.StringRequest).%New(), request.StringValue = "test"
        set sc = operation.HandlePrompt(request, .response)
        do ..Check($$$ISERR(sc), "missing agent configuration")
        set operation.AgentName = "no-such-agent"
        set sc = operation.HandlePrompt(request, .response)
        do ..Check($$$ISERR(sc), "nonexistent agent")

        set sc = ##class(App.Governance.Model).Create({"name":"bpl-model-test", "provider":"nim", "modelId":"bpl-fixture", "baseUrl":"http://127.0.0.1:18089/v1", "apiKey":"not-needed", "status":"approved", "enabled":true}, .ignored)
        do ..Require(sc)
        set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM App_Governance.Tool WHERE ClassName='App.Demo.InventoryTools' AND MethodName='SearchInventory'")
        if 'rs.%Next() throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Inventory tool fixture missing"))
        set toolName = rs.%Get("Name")
        set sc = ##class(App.Governance.Agent).Create({"name":"bpl-agent-test", "modelName":"bpl-model-test", "status":"approved", "enabled":true, "tools":[(toolName)], "policies":["database-audit"]}, .ignored)
        do ..Require(sc)
        set sc = ##class(App.Governance.Agent).Create({"name":"bpl-draft-test", "modelName":"bpl-model-test", "status":"draft", "enabled":true}, .ignored)
        do ..Require(sc)
        set operation.AgentName = "bpl-draft-test"
        set sc = operation.HandlePrompt(request, .response)
        do ..Check($$$ISERR(sc), "draft agent")

        set sc = ##class(App.Interop.ContextSearch).Agents(.caption, .top, .choices, .parameters, "BPL-")
        do ..Require(sc)
        do ..Check(($get(choices(1)) = "bpl-agent-test") && ('$data(choices(2))), "database agent selector and case-insensitive filtering")

        set operation.AgentName = "bpl-agent-test", request.StringValue = "   "
        set sc = operation.HandlePrompt(request, .response)
        do ..Check($$$ISERR(sc), "blank prompt")
        set request.StringValue = "permission test"
        set sc = operation.HandlePrompt(request, .response)
        do ..Check($$$ISERR(sc), "unauthorized production user")
        do ..Check(##class(App.AIHub.RuntimeContext).GetAgent() = "", "context cleared after denied call")

        for username = $username, "_Ensemble" {
            set user = ##class(App.Governance.AIUser).%New(), user.Username = username, user.Enabled = 1
            do ..Require(user.%Save())
            set permission = ##class(App.Governance.AgentUser).%New(), permission.Username = username, permission.AgentName = "bpl-agent-test", permission.Enabled = 1
            do ..Require(permission.%Save())
        }
        set request.StringValue = $char(67,97,102,233,32,28450,23383)
        set sc = operation.HandlePrompt(request, .response)
        do ..Require(sc)
        do ..Check(response.StringValue = ("BPL_OK:" _ request.StringValue), "plain text Unicode reply")
        do ..Check(##class(App.AIHub.RuntimeContext).GetRequestId() = "", "context cleared after success")
        write "DIRECT_AGENT_OK", !

        set sc = ##class(App.Governance.Agent).Update("bpl-agent-test", {"enabled":false}, .ignored)
        do ..Require(sc)
        set sc = operation.HandlePrompt(request, .response)
        do ..Check($$$ISERR(sc), "agent disabled after operation was created")
        set sc = ##class(App.Governance.Agent).Update("bpl-agent-test", {"enabled":true}, .ignored)
        do ..Require(sc)

        do ..Require(##class(Ens.Director).StopProduction(30, 1))
        do ..Require(##class(Ens.Director).StartProduction("App.Test.BPLProduction"))
        do ..Require(##class(Ens.Director).CreateBusinessService("BPL Service", .service))
        set request.StringValue = "queued BPL integration"
        set sc = service.ProcessInput(request, .response)
        do ..Require(sc)
        do ..Check(response.StringValue = "BPL_OK:queued BPL integration", "BPL call through queued operation")
        write "QUEUED_BPL_OK", !

        set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM App_Governance.AuditEvent WHERE AgentName='bpl-agent-test' AND ToolName=? AND Success=1", toolName)
        do rs.%Next()
        do ..Check(rs.%Get("N") = 2, "agent tool audit for direct and BPL calls")
        set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM App_Governance.ChatConversation WHERE AgentName='bpl-agent-test'")
        do rs.%Next()
        do ..Check(rs.%Get("N") = 2, "independent conversation for each prompt")
        set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Ens.MessageHeader WHERE TargetConfigName='BPL Agent' AND MessageBodyClassName='Ens.StringRequest'")
        do rs.%Next()
        do ..Check(rs.%Get("N") > 0, "string request visible in interoperability trace")
    } catch exception {
        set ..Failures = ..Failures + 1
        write "FAIL exception: ", exception.DisplayString(), !
    }
    set service = "", operation = ""
    set stopped = ##class(Ens.Director).StopProduction(30, 1)
    do ##class(App.AIHub.RuntimeContext).Clear()
    write "BPL_AGENT_FAILURES=", ..Failures, !
    return ..Failures
}

}
