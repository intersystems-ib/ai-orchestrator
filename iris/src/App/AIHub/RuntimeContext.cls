/// Process-local context used while AI Hub materializes and executes an agent.
Class App.AIHub.RuntimeContext
{

ClassMethod SetAgent(agentName As %String)
{
    set ^||AppAIHubRuntime("agent") = agentName
}

ClassMethod GetAgent() As %String
{
    quit $get(^||AppAIHubRuntime("agent"))
}

ClassMethod Clear()
{
    kill ^||AppAIHubRuntime
}

}
