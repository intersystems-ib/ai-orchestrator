Include %occStatus

/// Mandatory authorization policy backed by the IRIS user and agent assignments.
Class App.AIHub.Policy.UserAccess Extends %AI.Policy.Authorization
{

ClassMethod Check(username As %String = "", agentName As %String = "") As %Status
{
    if username = "" set username = $username
    if '##class(App.Governance.AIUser).IsAuthorized(username) {
        quit $$$ERROR($$$GeneralError, "IRIS user is not authorized to use AI agents: " _ username)
    }
    if agentName '= "", '##class(App.Governance.AgentUser).IsAuthorized(username, agentName) {
        quit $$$ERROR($$$GeneralError, "IRIS user is not authorized to use agent " _ agentName _ ": " _ username)
    }
    quit $$$OK
}

Method %CanList(tool As %String, metadata As %DynamicObject) As %Boolean
{
    quit ##class(App.Governance.AgentUser).IsAuthorized(
        ##class(App.AIHub.RuntimeContext).GetUsername(),
        ##class(App.AIHub.RuntimeContext).GetAgent())
}

Method %CanExecute(tool As %String, call As %DynamicObject,
    metadata As %DynamicObject) As %Status
{
    quit ..Check(##class(App.AIHub.RuntimeContext).GetUsername(),
        ##class(App.AIHub.RuntimeContext).GetAgent())
}

}
