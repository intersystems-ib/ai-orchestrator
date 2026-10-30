Include %occStatus

/// BPL operation: send StringValue as a prompt to one configured governed agent.
Class App.Interop.AgentOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "";
Parameter INVOCATION = "Queue";
Parameter SETTINGS = "AgentName:Basic:selector?context={App.Interop.ContextSearch/Agents}";

/// Logical name of an approved and enabled agent in AI Orchestrator.
Property AgentName As %String(MAXLEN = 120);

Method OnInit() As %Status
{
    set sc = ##super()
    if $$$ISERR(sc) quit sc
    quit ..ValidateAgent(..AgentName)
}

ClassMethod ValidateAgent(agentName As %String) As %Status
{
    if agentName = "" quit $$$ERROR($$$GeneralError, "AgentName must select an AI Orchestrator agent")
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Agent WHERE Name = ? AND Status = 'approved' AND Enabled = 1", agentName)
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "The configured agent is not approved and enabled: " _ agentName)
    quit $$$OK
}

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Ens.StringRequest">
    <Method>HandlePrompt</Method>
  </MapItem>
</MapItems>
}

/// Each message starts an independent conversation under the production job's IRIS user.
Method HandlePrompt(pRequest As Ens.StringRequest,
    Output pResponse As Ens.StringResponse) As %Status
{
    set pResponse = ##class(Ens.StringResponse).%New()
    set sc = ..ValidateAgent(..AgentName)
    if $$$ISERR(sc) quit sc
    if $zstrip(pRequest.StringValue, "<>W") = "" {
        quit $$$ERROR($$$GeneralError, "The prompt in StringValue cannot be empty")
    }

    set request = ##class(App.Interop.Message.ChatRequest).%New()
    set request.RequestId = $translate($SYSTEM.Util.CreateGUID(), "{}", "")
    set request.AgentName = ..AgentName
    set request.Message = pRequest.StringValue
    set request.Username = $username
    set request.RequestedAt = $zdatetime($horolog, 3)
    set request.Purpose = "bpl"
    set sc = ##class(App.Interop.LLMOperation).Execute(request, .result)
    if $$$ISERR(sc) quit sc
    if 'result.Success quit $$$ERROR($$$GeneralError, result.Error)
    set content = {}.%FromJSON(result.ResultJSON)
    set pResponse.StringValue = content.%Get("content")
    quit $$$OK
}

}
