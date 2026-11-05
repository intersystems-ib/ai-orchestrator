Include %occStatus

/// Imports a complete remote catalog atomically, preserving local governance.
Class App.AIHub.MCP.Catalog
{

ClassMethod Synchronize(serverName As %String, Output result As %DynamicObject) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, EndpointUrl, AuthMode, BearerSecret FROM App_Governance.MCPServer " _
        "WHERE Name = ? AND Status = 'approved' AND Enabled = 1", serverName)
    if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() return $$$ERROR($$$GeneralError, "MCP server is not approved and enabled")
    set serverId = rs.%Get("ID")
    set endpoint = rs.%Get("EndpointUrl"), authMode = rs.%Get("AuthMode"), secret = rs.%Get("BearerSecret")
    set sc = ##class(App.AIHub.MCP.Client).Execute(serverName, "tools/list", {}, .catalog)
    if $$$ISERR(sc) return sc
    set tools = catalog.%Get("tools")
    set created = 0, updated = 0, unavailable = 0
    kill seen
    tstart
    try {
        set server = ##class(App.Governance.MCPServer).%OpenId(serverId)
        if (server.EndpointUrl '= endpoint) || (server.AuthMode '= authMode) || (server.BearerSecret '= secret) || (server.Status '= "approved") || 'server.Enabled {
            throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "MCP server configuration changed during discovery; try again"))
        }
        for index = 0:1:(tools.%Size() - 1) {
            set remote = tools.%Get(index)
            set remoteName = remote.%Get("name")
            if $length(remoteName) > 1000 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "MCP tool name is too long"))
            set seen(remoteName) = 1
            set existing = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT ID FROM App_Governance.Tool WHERE MCPServerName = ? AND RemoteToolName = ?", server.Name, remoteName)
            if existing.%SQLCODE < 0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError, existing.%SQLCODE, existing.%Message))
            if existing.%Next() {
                set item = ##class(App.Governance.Tool).%OpenId(existing.%Get("ID"))
                set updated = updated + 1
            } else {
                set item = ##class(App.Governance.Tool).%New()
                set item.Name = ..LocalName(serverId, remoteName)
                set item.ClassName = "App.AIHub.Tool.RemoteMCP"
                set item.MethodName = item.Name
                set item.MCPServerName = server.Name
                set item.RemoteToolName = remoteName
                set item.Status = "approved", item.Enabled = 1
                set item.CreatedAt = $zdatetime($horolog, 3)
                set created = created + 1
            }
            set item.Description = remote.%Get("description", "")
            set item.RemoteAvailable = 1
            set descriptor = {"name":(item.Name), "description":(item.Description),
                "source":"iris", "provider":"App.AIHub.Tool.RemoteMCP",
                "parameters":(remote.%Get("inputSchema")), "returns":(remote.%Get("outputSchema", {"type":"object"}))}
            do descriptor.%Set("requires_auth", item.RequiresApproval, "boolean")
            do descriptor.%Set("stateful", 1, "boolean")
            set item.DescriptorJSON = descriptor.%ToJSON()
            set sc = item.%Save()
            if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        }
        set old = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID, RemoteToolName FROM App_Governance.Tool WHERE MCPServerName = ?", server.Name)
        if old.%SQLCODE < 0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError, old.%SQLCODE, old.%Message))
        while old.%Next() {
            if $data(seen(old.%Get("RemoteToolName"))) continue
            set item = ##class(App.Governance.Tool).%OpenId(old.%Get("ID"))
            if 'item.RemoteAvailable continue
            set item.RemoteAvailable = 0
            set sc = item.%Save()
            if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
            set unavailable = unavailable + 1
        }
        set server.LastDiscoveryAt = $zdatetime($horolog, 3)
        set sc = server.%Save()
        if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
    } catch exception {
        set sc = exception.AsStatus()
    }
    if $$$ISERR(sc) { trollback  return sc }
    tcommit
    set result = {"serverName":(serverName), "created":(created), "updated":(updated),
        "unavailable":(unavailable), "tools":(##class(App.Governance.Tool).ListJSON(serverName))}
    return $$$OK
}

ClassMethod LocalName(serverId As %Integer, remoteName As %String) As %String
{
    set label = "", allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    for i = 1:1:$length(remoteName) {
        set character = $extract(remoteName, i)
        set label = label _ $select($find(allowed, character):character, 1:"_")
        if $length(label) >= 32 quit
    }
    return "mcp_" _ serverId _ "_" _ label _ "_" _ ..NameDigest(remoteName)
}

ClassMethod NameDigest(name As %String) As %String [ Language = python ]
{
    import hashlib
    return hashlib.sha256(name.encode("utf-8")).hexdigest()[:12]
}

}
