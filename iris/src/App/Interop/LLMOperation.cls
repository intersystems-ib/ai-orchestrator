Include %occStatus

/// The only production component allowed to invoke an AI Hub agent.
Class App.Interop.LLMOperation Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="App.Interop.Message.ChatRequest">
    <Method>HandleChat</Method>
  </MapItem>
</MapItems>
}

Method HandleChat(pRequest As App.Interop.Message.ChatRequest,
    Output pResponse As App.Interop.Message.ChatResponse) As %Status
{
    set startedAt = $zh
    set pResponse = ##class(App.Interop.Message.ChatResponse).%New()
    set pResponse.RequestId = pRequest.RequestId
    set pResponse.AgentName = pRequest.AgentName
    set pResponse.Username = pRequest.Username

    do ##class(App.AIHub.RuntimeContext).SetRequest(
        pRequest.RequestId, pRequest.Username)
    try {
        set sc = ##class(App.AIHub.Policy.UserAccess).Check(
            pRequest.Username, pRequest.AgentName)
        if $$$ISERR(sc) {
            set pResponse.HttpStatus = 403
        } else {
            set sc = ##class(App.AIHub.ChatService).Send(
                pRequest.AgentName, pRequest.Message,
                pRequest.ConversationId, pRequest.Username, .result)
            if $$$ISOK(sc) {
                set pResponse.Success = 1
                set pResponse.HttpStatus = 200
                set pResponse.ResultJSON = result.%ToJSON()
            }
        }
    } catch exception {
        set sc = exception.AsStatus()
    }

    if $$$ISERR(sc) set pResponse.Error = $SYSTEM.Status.GetErrorText(sc)
    set pResponse.CompletedAt = $zdatetime($horolog, 3)
    set pResponse.DurationMs = ..ElapsedMilliseconds(startedAt, $zh)
    do ##class(App.AIHub.RuntimeContext).Clear()

    // Business errors travel in the response so both request and response
    // remain available in the interoperability message trace.
    quit $$$OK
}

ClassMethod ElapsedMilliseconds(startedAt As %String,
    finishedAt As %String) As %Integer [ Internal, Private ]
{
    set elapsed = ($piece(finishedAt, ",", 1) - $piece(startedAt, ",", 1)) * 86400
    set elapsed = elapsed + $piece(finishedAt, ",", 2) - $piece(startedAt, ",", 2)
    quit $justify(elapsed * 1000, 0, 0)
}

}
