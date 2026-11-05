Include %occStatus

/// Streamable HTTP MCP client. A short-lived session is used for each operation.
Class App.AIHub.MCP.Client
{

ClassMethod Execute(serverName As %String, method As %String,
    parameters As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.MCPServer WHERE Name = ? " _
        "AND Status = 'approved' AND Enabled = 1", serverName)
    if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() return $$$ERROR($$$GeneralError, "MCP server is not approved and enabled: " _ serverName)
    set server = ##class(App.Governance.MCPServer).%OpenId(rs.%Get("ID"))
    set token = ""
    if server.AuthMode = "bearer" {
        try {
            set sc = ##class(%ConfigStore.Configuration).ResolveSecretReference(server.BearerSecret, .token)
        } catch exception {
            set sc = exception.AsStatus()
        }
        if $$$ISERR(sc) return $$$ERROR($$$GeneralError, "Could not resolve the MCP server token from Secure Wallet")
        if token = "" return $$$ERROR($$$GeneralError, "The MCP server token is empty")
    }
    set connection = ##class(App.AIHub.MCP.Connection).%New()
    set sc = $$$OK
    try {
        set sc = connection.Open(server.EndpointUrl, token)
        if $$$ISOK(sc) {
            if method = "tools/list" {
                set sc = connection.ListTools(.result)
            } elseif method = "tools/call" {
                set sc = connection.Call(method, parameters, .result)
            } else {
                set sc = $$$ERROR($$$GeneralError, "Unsupported MCP operation")
            }
        }
    } catch exception {
        set sc = exception.AsStatus()
    }
    do connection.Close()
    return sc
}

}
