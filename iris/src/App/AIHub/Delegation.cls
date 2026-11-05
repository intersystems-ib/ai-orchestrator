Include %occStatus

/// Execute a specialist in its own IRIS job. Native AI Hub callbacks must not
/// re-enter a provider runtime that is still executing the caller's tool loop.
Class App.AIHub.Delegation
{

ClassMethod Send(target As %String, prompt As %String,
    Output result As %DynamicObject) As %Status
{
    set key = $translate($SYSTEM.Util.CreateGUID(), "{}", "")
    set input = {"target":(target), "prompt":(prompt),
        "context":(##class(App.AIHub.RuntimeContext).Snapshot())}
    set ^AppAgentDelegation(key, "input") = input.%ToJSON()
    set sc = $$$OK
    try {
        job ##class(App.AIHub.Delegation).Run(key)
        set started = $zh
        while '$data(^AppAgentDelegation(key, "done")) {
            if ($zh - started) > 120 {
                throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "Delegated agent exceeded the 120 second timeout"))
            }
            hang 0.05
        }
        set sc = ^AppAgentDelegation(key, "status")
        do ##class(App.AIHub.RuntimeContext).SetDelegateCalls(^AppAgentDelegation(key, "calls"))
        if $$$ISOK(sc) set result = {}.%FromJSON(^AppAgentDelegation(key, "result"))
    } catch exception {
        set sc = exception.AsStatus()
    }
    // A late worker checks this marker under the same lock before publishing.
    lock +^AppAgentDelegation(key)
    kill ^AppAgentDelegation(key)
    lock -^AppAgentDelegation(key)
    return sc
}

ClassMethod Run(key As %String)
{
    set sc = $$$OK, result = {}
    try {
        set input = {}.%FromJSON(^AppAgentDelegation(key, "input"))
        set context = input.%Get("context")
        do ##class(App.AIHub.RuntimeContext).Restore(context)
        do ##class(App.AIHub.RuntimeContext).SetDelegateCalls(context.%Get("delegateCalls"))
        set sc = ##class(App.AIHub.ChatService).Send(input.%Get("target"), input.%Get("prompt"),
            "", context.%Get("username"), .result)
    } catch exception {
        set sc = exception.AsStatus()
    }
    lock +^AppAgentDelegation(key)
    if $data(^AppAgentDelegation(key, "input")) {
        set ^AppAgentDelegation(key, "status") = sc
        set ^AppAgentDelegation(key, "calls") = ##class(App.AIHub.RuntimeContext).GetDelegateCalls()
        if $$$ISOK(sc) set ^AppAgentDelegation(key, "result") = result.%ToJSON()
        set ^AppAgentDelegation(key, "done") = 1
    }
    lock -^AppAgentDelegation(key)
    do ##class(App.AIHub.RuntimeContext).Clear()
}

}
