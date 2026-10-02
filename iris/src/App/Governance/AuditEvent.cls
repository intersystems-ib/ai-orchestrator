Include %occStatus

/// Immutable audit trail for governed tool executions.
Class App.Governance.AuditEvent Extends %Persistent
{

Property AgentName As %String(MAXLEN = 120);
Property RequestId As %String(MAXLEN = 64);
Property ToolName As %String(MAXLEN = 120) [ Required ];
Property PolicyName As %String(MAXLEN = 120);
Property Arguments As %String(MAXLEN = "");
Property ResultPreview As %String(MAXLEN = 2000);
Property Success As %Boolean;
Property DurationMs As %Integer;
Property Error As %String(MAXLEN = 2000);
Property CreatedAt As %TimeStamp;

Index CreatedIndex On CreatedAt;
Index AgentToolIndex On (AgentName, ToolName);

ClassMethod Record(agentName As %String, policyName As %String, call As %DynamicObject,
    result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
    set item = ..%New()
    set item.AgentName = agentName
    set item.RequestId = ##class(App.AIHub.RuntimeContext).GetRequestId()
    set item.ToolName = call.%Get("name", "")
    set item.PolicyName = policyName
    if $isobject(call) set item.Arguments = call.%ToJSON()
    if $isobject(result) set item.ResultPreview = $extract(result.%ToJSON(), 1, 2000)
    set item.Success = $$$ISOK(status)
    set item.DurationMs = duration
    if $$$ISERR(status) set item.Error = $extract($SYSTEM.Status.GetErrorText(status), 1, 2000)
    set item.CreatedAt = $zdatetime($horolog, 3)
    quit item.%Save()
}

ClassMethod ListJSON(limit As %Integer = 100) As %DynamicArray
{
    if (limit < 1) || (limit > 1000) set limit = 100
    set output = []
    set statement = ##class(%SQL.Statement).%New()
    set sc = statement.%Prepare(
        "SELECT TOP ? ID, AgentName, RequestId, ToolName, PolicyName, Arguments, ResultPreview, " _
        "Success, DurationMs, Error, CreatedAt FROM App_Governance.AuditEvent " _
        "ORDER BY CreatedAt DESC")
    if $$$ISERR(sc) quit output
    set rs = statement.%Execute(limit)
    while rs.%Next() {
        do output.%Push({
            "id":(rs.%Get("ID")), "agentName":(rs.%Get("AgentName")),
            "requestId":(rs.%Get("RequestId")),
            "toolName":(rs.%Get("ToolName")), "policyName":(rs.%Get("PolicyName")),
            "arguments":(rs.%Get("Arguments")), "resultPreview":(rs.%Get("ResultPreview")),
            "success":(rs.%Get("Success")), "durationMs":(rs.%Get("DurationMs")),
            "error":(rs.%Get("Error")), "createdAt":(rs.%Get("CreatedAt"))
        })
    }
    quit output
}

}
