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
    quit $get(^||AppAIHubRuntime("agent"))
}

ClassMethod GetRequestId() As %String
{
    quit $get(^||AppAIHubRuntime("requestId"))
}

ClassMethod GetUsername() As %String
{
    quit $get(^||AppAIHubRuntime("username"), $username)
}

ClassMethod Clear()
{
    kill ^||AppAIHubRuntime
}

}
