Include %occStatus

/// Dependency-aware registry deletion. Historical conversations/audits remain.
Class App.Governance.Deletion
{
ClassMethod Execute(kind As %String, name As %String, Output result As %DynamicObject,
    Output httpStatus As %Integer) As %Status
{
    set httpStatus=400
    set table=$select(kind="model":"Model",kind="agent":"Agent",kind="mcp-server":"MCPServer",1:"")
    if table="" return $$$ERROR($$$GeneralError,"Unsupported resource type")
    tstart
    try {
        set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM App_Governance."_table_" WHERE Name=?",name)
        if rs.%SQLCODE<0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message))
        if 'rs.%Next() {set httpStatus=404 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Resource does not exist: "_name))}
        set id=rs.%Get("ID"),httpStatus=409
        if kind="model" {
            do ..RequireUnused("SELECT Name FROM App_Governance.Agent WHERE ModelName=?",name,"Model is used by agents")
            set fqn=##class(App.Governance.Model).ConfigurationFQN(id)
            if ##class(%ConfigStore.Configuration).Exists(fqn) {
                set sc=##class(%ConfigStore.Configuration).Delete(fqn)
                if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            }
        }
        if kind="agent" {
            do ..RequireUnused("SELECT AgentName AS Name FROM App_Governance.AgentDelegate WHERE DelegateName=?",name,"Agent is used by other agents")
            do ..CheckProductions(name)
            do ..SQLDelete("DELETE FROM App_Governance.AgentTool WHERE AgentName=?",name)
            do ..SQLDelete("DELETE FROM App_Governance.AgentDelegate WHERE AgentName=?",name)
            do ..SQLDelete("DELETE FROM App_Governance.AgentUser WHERE AgentName=?",name)
        }
        if kind="mcp-server" {
            do ..RequireUnused("SELECT DISTINCT a.AgentName AS Name FROM App_Governance.AgentTool a JOIN App_Governance.Tool t ON t.Name=a.ToolName WHERE t.MCPServerName=?",name,"MCP server tools are assigned to agents")
            do ..SQLDelete("DELETE FROM App_Governance.Tool WHERE MCPServerName=?",name)
        }
        set httpStatus=400
        set sc=$classmethod("App.Governance."_table,"%DeleteId",id)
        if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        tcommit
        set httpStatus=200,result={"deleted":true,"name":(name),"type":(kind)}
        return $$$OK
    } catch exception {
        trollback 1
        return exception.AsStatus()
    }
}

ClassMethod RequireUnused(sql As %String, name As %String, reason As %String) [ Private ]
{
    set rs=##class(%SQL.Statement).%ExecDirect(,sql,name)
    if rs.%SQLCODE<0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message))
    if rs.%Next() throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,reason_": "_rs.%Get("Name")_". Remove the assignment first."))
}

ClassMethod SQLDelete(sql As %String, name As %String) [ Private ]
{
    set rs=##class(%SQL.Statement).%ExecDirect(,sql,name)
    if rs.%SQLCODE<0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message))
}

ClassMethod CheckProductions(name As %String) [ Private ]
{
    set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Ens_Config.Production")
    if rs.%SQLCODE<0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message))
    while rs.%Next() {
        set production=##class(Ens.Config.Production).%OpenId(rs.%Get("ID"))
        for i=1:1:production.Items.Count() {
            set item=production.Items.GetAt(i)
            for collection="Settings","ModifiedSettings" {
                set settings=$property(item,collection)
                for j=1:1:settings.Count() {
                    set setting=settings.GetAt(j)
                    if (setting.Name="AgentName") && ($zconvert(setting.Value,"U")=$zconvert(name,"U")) {
                        throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"Agent is configured in production "_production.Name_", operation "_item.Name_". Remove the setting first."))
                    }
                }
            }
        }
    }
}
}
