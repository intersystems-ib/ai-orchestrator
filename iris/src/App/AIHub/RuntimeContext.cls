Include %occStatus

/// Process-local context used while AI Hub materializes and executes an agent.
Class App.AIHub.RuntimeContext
{

ClassMethod SetAgent(agentName As %String)
{
    set ^||AppAIHubRuntime("agent") = agentName
}

ClassMethod SetRequest(requestId As %String, username As %String)
{
    set ^||AppAIHubRuntime("requestId") = requestId
    set ^||AppAIHubRuntime("username") = username
}

ClassMethod GetAgent() As %String
{
    return $get(^||AppAIHubRuntime("agent"))
}

ClassMethod GetRequestId() As %String
{
    return $get(^||AppAIHubRuntime("requestId"))
}

ClassMethod GetUsername() As %String
{
    return $get(^||AppAIHubRuntime("username"), $username)
}

ClassMethod Clear()
{
    kill ^||AppAIHubRuntime
}

/// Save only the current execution frame; the request-wide call budget is shared.
ClassMethod Snapshot() As %DynamicObject
{
    return {"agent":(..GetAgent()), "requestId":(..GetRequestId()), "username":(..GetUsername()),
        "path":($get(^||AppAIHubRuntime("path"))), "depth":($get(^||AppAIHubRuntime("depth"), 0)),
        "delegateCalls":(..GetDelegateCalls())}
}

ClassMethod Restore(snapshot As %DynamicObject)
{
    do ..SetAgent(snapshot.%Get("agent"))
    do ..SetRequest(snapshot.%Get("requestId"), snapshot.%Get("username"))
    set ^||AppAIHubRuntime("path") = snapshot.%Get("path")
    set ^||AppAIHubRuntime("depth") = snapshot.%Get("depth")
}

ClassMethod EnterDelegate(agentName As %String) As %Status
{
    set path = $get(^||AppAIHubRuntime("path"), ..GetAgent())
    if path = "" set path = ..GetAgent()
    if $find("," _ $zconvert(path, "U") _ ",", "," _ $zconvert(agentName, "U") _ ",") {
        return $$$ERROR($$$GeneralError, "Recursive agent delegation is not allowed")
    }
    if $get(^||AppAIHubRuntime("depth"), 0) >= 3 {
        return $$$ERROR($$$GeneralError, "Agent delegation exceeds the maximum depth of 3")
    }
    if $get(^||AppAIHubRuntime("delegateCalls"), 0) >= 16 {
        return $$$ERROR($$$GeneralError, "Agent delegation exceeds the request limit of 16 calls")
    }
    set ^||AppAIHubRuntime("delegateCalls") = $get(^||AppAIHubRuntime("delegateCalls"), 0) + 1
    set ^||AppAIHubRuntime("depth") = $get(^||AppAIHubRuntime("depth"), 0) + 1
    set ^||AppAIHubRuntime("path") = path _ "," _ agentName
    return $$$OK
}

ClassMethod GetDelegateCalls() As %Integer
{
    return $get(^||AppAIHubRuntime("delegateCalls"), 0)
}

ClassMethod SetDelegateCalls(count As %Integer)
{
    set ^||AppAIHubRuntime("delegateCalls") = count
}

}
