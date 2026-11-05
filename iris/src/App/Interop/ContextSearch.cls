Include %occStatus

/// Native Management Portal selector for agents stored in this namespace.
Class App.Interop.ContextSearch Extends %ZEN.Portal.ContextSearch
{

ClassMethod Agents(Output pCaption As %String, Output pTopResults,
    Output pResults, ByRef pParms As %String, pSearchKey As %String = "") As %Status
{
    set pCaption = "Approved AI Orchestrator agents"
    kill pTopResults, pResults
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM App_Governance.Agent WHERE Status = 'approved' AND Enabled = 1 ORDER BY Name")
    if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    set index = 0
    while rs.%Next() {
        set name = rs.%Get("Name")
        if pSearchKey '= "", '$find($zconvert(name, "L"), $zconvert(pSearchKey, "L")) continue
        set index = index + 1, pResults(index) = name
    }
    return $$$OK
}

}
