Include %occStatus

/// Registry of external MCP endpoints. Discovery is a separate operation.
Class App.Governance.MCPServer Extends %Persistent
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property Description As %String(MAXLEN = 1000);
Property EndpointUrl As %String(MAXLEN = 2000) [ Required ];
Property Transport As %String(VALUELIST = ",streamable-http") [ InitialExpression = "streamable-http" ];
Property AuthMode As %String(VALUELIST = ",none,bearer") [ InitialExpression = "none" ];
/// Secure Wallet reference only; never a plaintext token.
Property BearerSecret As %String(MAXLEN = 500);
Property Status As %String(VALUELIST = ",draft,approved,suspended,retired") [ InitialExpression = "draft" ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property CreatedAt As %TimeStamp;
Property LastDiscoveryAt As %TimeStamp;

Index NameIndex On Name [ Unique ];

ClassMethod Create(payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set name = payload.%Get("name", "")
    if '##class(App.Governance.ClassUtil).ValidName(name) {
        return $$$ERROR($$$GeneralError, "name is required and cannot contain commas")
    }
    set item = ..%New()
    set item.Name = name
    set item.DisplayName = name
    set item.CreatedAt = $zdatetime($horolog, 3)
    return ..SavePayload(item, payload, .result)
}

ClassMethod Update(name As %String, payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.MCPServer WHERE Name = ?", name)
    if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() return $$$ERROR($$$GeneralError, "MCP server does not exist: " _ name)
    set item = ..%OpenId(rs.%Get("ID"))
    return ..SavePayload(item, payload, .result)
}

ClassMethod SavePayload(item As App.Governance.MCPServer, payload As %DynamicObject,
    Output result As %DynamicObject) As %Status [ Private ]
{
    set oldEndpoint = item.EndpointUrl, oldAuth = item.AuthMode, oldSecret = item.BearerSecret
    set item.DisplayName = payload.%Get("displayName", item.DisplayName)
    set item.Description = payload.%Get("description", item.Description)
    set item.EndpointUrl = payload.%Get("endpointUrl", item.EndpointUrl)
    set item.Transport = payload.%Get("transport", item.Transport)
    set item.AuthMode = payload.%Get("authMode", item.AuthMode)
    set item.BearerSecret = payload.%Get("bearerSecret", item.BearerSecret)
    set item.Status = payload.%Get("status", item.Status)
    set item.Enabled = payload.%Get("enabled", item.Enabled)
    set url = item.EndpointUrl
    if ($extract(url, 1, 7) '= "http://") && ($extract(url, 1, 8) '= "https://") {
        return $$$ERROR($$$GeneralError, "endpointUrl must use http:// or https://")
    }
    set host = $piece($piece(url, "://", 2), "/", 1)
    if (host = "") || $find(host, "@") || $find(url, "?") || $find(url, "#") {
        return $$$ERROR($$$GeneralError, "endpointUrl must have a host and no embedded credentials, query or fragment")
    }
    if $translate(url, " " _ $char(9, 10, 13), "") '= url {
        return $$$ERROR($$$GeneralError, "endpointUrl cannot contain whitespace")
    }
    if item.AuthMode = "none" set item.BearerSecret = ""
    if item.AuthMode = "bearer", ($extract(item.BearerSecret, 1, 9) '= "secret://") || ($length(item.BearerSecret) < 10) {
        return $$$ERROR($$$GeneralError, "bearerSecret must be a secret:// Secure Wallet reference")
    }
    set changed = (oldEndpoint '= item.EndpointUrl) || (oldAuth '= item.AuthMode) || (oldSecret '= item.BearerSecret)
    if changed set item.LastDiscoveryAt = ""
    tstart
    set sc = item.%Save()
    if $$$ISERR(sc) { trollback  return sc }
    if changed {
        set invalidated = ##class(%SQL.Statement).%ExecDirect(,
            "UPDATE App_Governance.Tool SET RemoteAvailable = 0 WHERE MCPServerName = ?", item.Name)
        if invalidated.%SQLCODE < 0 { trollback  return $$$ERROR($$$SQLError, invalidated.%SQLCODE, invalidated.%Message) }
    }
    tcommit
    set result = ..OneJSON(item)
    return $$$OK
}

ClassMethod OneJSON(item As App.Governance.MCPServer) As %DynamicObject [ Private ]
{
    return {"id":(item.%Id()), "name":(item.Name), "displayName":(item.DisplayName),
        "description":(item.Description), "endpointUrl":(item.EndpointUrl),
        "transport":(item.Transport), "authMode":(item.AuthMode),
        "bearerSecret":(item.BearerSecret), "status":(item.Status),
        "enabled":(item.Enabled), "createdAt":(item.CreatedAt), "lastDiscoveryAt":(item.LastDiscoveryAt)}
}

ClassMethod ListJSON() As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.MCPServer ORDER BY Name")
    while rs.%Next() {
        do output.%Push(..OneJSON(..%OpenId(rs.%Get("ID"))))
    }
    return output
}

}
