Include %occStatus

/// Initializes mandatory AI Hub governance resources.
Class App.AIHub.Bootstrap
{

ClassMethod Seed() As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.AIUser WHERE Username = ?", "CSPSystem")
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() {
        set sc = ##class(App.Governance.AIUser).Set(
            {"username":"CSPSystem", "enabled":true}, .ignored)
        if $$$ISERR(sc) quit sc
    }

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Policy WHERE Name = ?", "iris-user-access")
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() {
        set payload = {
            "name":"iris-user-access",
            "displayName":"IRIS AI user access",
            "className":"App.AIHub.Policy.UserAccess",
            "type":"authorization",
            "description":"Allows AI calls and tool execution only for enabled IRIS users",
            "status":"approved",
            "enabled":true
        }
        set sc = ##class(App.Governance.Policy).Create(payload, .ignored)
        if $$$ISERR(sc) quit sc
    }

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Policy WHERE Name = ?", "database-audit")
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() {
        set payload = {
            "name":"database-audit",
            "displayName":"IRIS database audit",
            "className":"App.AIHub.Policy.DatabaseAudit",
            "type":"audit",
            "description":"Persists governed tool executions as immutable audit events in IRIS",
            "status":"approved",
            "enabled":true
        }
        set sc = ##class(App.Governance.Policy).Create(payload, .ignored)
        if $$$ISERR(sc) quit sc
    }

    set sc = ##class(App.Governance.Tool).Synchronize(.ignored)
    if $$$ISERR(sc) quit sc

    set sc = ##class(App.Demo.Inventory).SeedDemo(.createdInventory)
    if $$$ISERR(sc) quit sc
    set sc = ##class(App.Demo.Inventory).%BuildIndices(
        $listbuild("NameSearchIndex"))
    if $$$ISERR(sc) quit sc
    set sc = ##class(App.Demo.Shipment).SeedDemo(.createdShipments)
    if $$$ISERR(sc) quit sc
    set sc = ##class(Ens.Director).SetAutoStart("App.Interop.Production")
    if $$$ISERR(sc) quit sc
    quit $$$OK
}

}
