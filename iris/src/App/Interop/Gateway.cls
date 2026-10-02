Include %occStatus

/// Application facade that submits LLM calls to the active production.
Class App.Interop.Gateway
{

ClassMethod Send(agentName As %String, message As %String,
    conversationId As %String = "", username As %String = "",
    purpose As %String = "chat", Output result As %DynamicObject,
    Output httpStatus As %Integer = 502) As %Status
{
    set request = ##class(App.Interop.Message.ChatRequest).%New()
    set request.RequestId = $translate($SYSTEM.Util.CreateGUID(), "{}", "")
    set request.AgentName = agentName
    set request.Message = message
    set request.ConversationId = conversationId
    set request.Username = username
    set request.Purpose = purpose
    set request.RequestedAt = $zdatetime($horolog, 3)

    set sc = ##class(Ens.Director).CreateBusinessService(
        "AI Governance API Service", .service)
    if $$$ISERR(sc) quit sc
    set sc = service.ProcessInput(request, .response)
    if $$$ISERR(sc) quit sc
    if '$isobject(response) quit $$$ERROR($$$GeneralError, "The interoperability production returned no response")

    set httpStatus = response.HttpStatus
    if 'response.Success quit $$$ERROR($$$GeneralError, response.Error)
    try {
        set result = {}.%FromJSON(response.ResultJSON)
    } catch exception {
        set sc = exception.AsStatus()
    }
    quit sc
}

}
