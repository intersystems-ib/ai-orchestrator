Include %occStatus

/// Built-in audit policy that persists every governed tool call in IRIS.
Class App.AIHub.Policy.DatabaseAudit Extends %AI.Policy.Audit
{

Method %LogExecution(call As %DynamicObject, metadata As %DynamicObject,
    result As %DynamicObject, duration As %Integer, status As %Status) As %Status
{
    quit ##class(App.Governance.AuditEvent).Record(
        ##class(App.AIHub.RuntimeContext).GetAgent(), "database-audit",
        call, result, duration, status)
}

}
