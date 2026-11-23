Include %occStatus

/// Explicit upgrade only: move existing tool identities to a verified MCP catalog.
Class App.AIHub.Upgrade.ExternalizeDemo
{
ClassMethod Run(serverName As %String="iris-demo",
    endpoint As %String="http://iris-demo-transport:8080/mcp") As %Status
{
    set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,EndpointUrl,Enabled,Status FROM App_Governance.MCPServer WHERE Name=?",serverName)
    if rs.%Next() {
        if (rs.%Get("EndpointUrl")'=endpoint)||'rs.%Get("Enabled")||(rs.%Get("Status")'="approved") {
            return $$$ERROR($$$GeneralError,"Existing MCP server has different configuration; refusing to replace it")
        }
    } else {
        set sc=##class(App.Governance.MCPServer).Create({"name":(serverName),"displayName":"Business examples",
            "description":"Isolated inventory and shipment examples","endpointUrl":(endpoint),
            "status":"approved","enabled":true},.ignored)
        if $$$ISERR(sc) return sc
    }
    set sc=##class(App.AIHub.MCP.Client).Execute(serverName,"tools/list",{},.catalog)
    if $$$ISERR(sc) return sc
    kill remote
    for i=0:1:(catalog.tools.%Size()-1) {
        set tool=catalog.tools.%Get(i), name=tool.%Get("name")
        for method="SearchInventory","AddInventoryItem","SearchShipmentsByProduct","SearchShipmentsByDateRange" {
            if $extract(name,*-$length(method),*)'=("_"_method) continue
            if $data(remote(method)) return $$$ERROR($$$GeneralError,"Ambiguous remote method: "_method)
            set remote(method)=tool
        }
    }
    for method="SearchInventory","AddInventoryItem","SearchShipmentsByProduct","SearchShipmentsByDateRange" {
        if '$data(remote(method)) return $$$ERROR($$$GeneralError,"Missing remote method: "_method)
    }
    tstart
    try {
        set rs=##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID FROM App_Governance.Tool WHERE ClassName IN ('App.Demo.InventoryTools','App.Demo.ShipmentTools') AND (MCPServerName IS NULL OR MCPServerName='')")
        if rs.%SQLCODE<0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message))
        while rs.%Next() {
            set item=##class(App.Governance.Tool).%OpenId(rs.%Get("ID")), method=item.MethodName
            if '$data(remote(method)) throw ##class(%Exception.General).%New("Unknown legacy tool: "_method)
            set tool=remote(method)
            set item.ClassName="App.AIHub.Tool.RemoteMCP", item.MethodName=item.Name
            set item.MCPServerName=serverName, item.RemoteToolName=tool.%Get("name"), item.RemoteAvailable=1
            set descriptor={"name":(item.Name),"description":(tool.%Get("description")),
                "source":"iris","provider":"App.AIHub.Tool.RemoteMCP",
                "parameters":(tool.%Get("inputSchema")),"returns":(tool.%Get("outputSchema",{"type":"object"}))}
            do descriptor.%Set("requires_auth",item.RequiresApproval,"boolean")
            do descriptor.%Set("stateful",1,"boolean")
            set item.Description=tool.%Get("description"), item.DescriptorJSON=descriptor.%ToJSON()
            set sc=item.%Save()
            if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        }
        tcommit
    } catch ex {
        trollback
        return ex.AsStatus()
    }
    // Existing names, IDs, approval states and agent allow-lists stay intact.
    set sc=##class(App.AIHub.MCP.Catalog).Synchronize(serverName,.ignored)
    if $$$ISERR(sc) return sc
    set ^AppDemoSeparation("catalogReady")=$zdatetime($horolog,3)
    return $$$OK
}
}
