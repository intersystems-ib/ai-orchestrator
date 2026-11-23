Include %occStatus

/// Backfill appended fields without changing existing explicit budgets.
Class App.AIHub.Upgrade.ContextBudgets
{
ClassMethod Run() As %Status
{
    set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM App_Governance.Model")
    if rs.%SQLCODE<0 return $$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message)
    while rs.%Next() {
        set item=##class(App.Governance.Model).%OpenId(rs.%Get("ID"))
        if item.MaxContextTokens="" {
            set item.MaxContextTokens=4096
            set sc=item.%Save()
            if $$$ISERR(sc) return sc
        }
    }
    set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM App_Governance.Agent")
    if rs.%SQLCODE<0 return $$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message)
    while rs.%Next() {
        set item=##class(App.Governance.Agent).%OpenId(rs.%Get("ID")), changed=0
        if item.ContextBudget="" { set item.ContextBudget=0, changed=1 }
        if item.ResponseReserve="" { set item.ResponseReserve=1024, changed=1 }
        if changed {
            set sc=item.%Save()
            if $$$ISERR(sc) return sc
        }
    }
    return $$$OK
}
}
