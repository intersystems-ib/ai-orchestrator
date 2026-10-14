Include %occStatus

/// One assigned remote tool exposed through the native AI Hub ToolManager.
Class App.AIHub.Tool.RemoteMCP Extends %AI.Tool
{

Property ToolName As %String [ Internal ];
Property Descriptor As %DynamicObject [ Internal ];

ClassMethod Create(toolName As %String, Output tool As App.AIHub.Tool.RemoteMCP) As %Status
{
    if '##class(App.Governance.Tool).IsAvailable(toolName) quit $$$ERROR($$$GeneralError, "MCP tool is not available: " _ toolName)
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT DescriptorJSON FROM App_Governance.Tool WHERE Name = ? AND MCPServerName <> ''", toolName)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "MCP tool does not exist")
    set tool = ..%New()
    set tool.ToolName = toolName
    set tool.Descriptor = {}.%FromJSON(rs.%Get("DescriptorJSON"))
    quit $$$OK
}

Method %Discover() As %DynamicObject
{
    set tools = []
    do tools.%Push(..Descriptor)
    quit {"tools":(tools)}
}

Method %Invoke(toolName As %String, args As %DynamicObject) As %Any
{
    if toolName '= ..ToolName quit ..%ToolError($$$ERROR($$$GeneralError, "MCP tool is not assigned to this adapter"))
    set agentName = ##class(App.AIHub.RuntimeContext).GetAgent()
    set sc = ##class(App.AIHub.Policy.UserAccess).Check(##class(App.AIHub.RuntimeContext).GetUsername(), agentName)
    if $$$ISERR(sc) quit ..%ToolError(sc)
    if '##class(App.Governance.AgentTool).IsAllowed(agentName, toolName) quit ..%ToolError($$$ERROR($$$GeneralError, "MCP tool is not assigned to this agent"))
    if '##class(App.Governance.Tool).IsAvailable(toolName) quit ..%ToolError($$$ERROR($$$GeneralError, "MCP tool or server is no longer available"))
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT MCPServerName, RemoteToolName FROM App_Governance.Tool WHERE Name = ?", toolName)
    if 'rs.%Next() quit ..%ToolError($$$ERROR($$$GeneralError, "MCP tool no longer exists"))
    set parameters = {"name":(rs.%Get("RemoteToolName")), "arguments":(args)}
    set sc = ##class(App.AIHub.MCP.Client).Execute(rs.%Get("MCPServerName"), "tools/call", parameters, .result)
    if $$$ISERR(sc) quit ..%ToolError(sc)
    if result.%Get("isError", 0) quit ..%ToolError($$$ERROR($$$GeneralError, "Remote MCP tool failed: " _ result.%ToJSON()))
    quit result
}

}
