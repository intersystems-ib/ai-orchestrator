Include %occStatus

/// Isolated registry deletion regression tests; never run against real data.
Class App.Test.Deletion Extends %RegisteredObject
{
Property Failures As %Integer [ InitialExpression = 0 ];
Method Check(ok As %Boolean, label As %String)
{
    if 'ok {set ..Failures=..Failures+1 write "FAIL ",label,!}
}
Method Require(sc As %Status)
{
    if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
}
Method Run() As %Integer
{
    try {
        do ..Require(##class(App.Governance.Model).Create({"name":"delete-model","provider":"nim","modelId":"fixture","apiKey":"not-needed","baseUrl":"http://localhost:18091/v1","status":"approved"},.model))
        set fqn=##class(App.Governance.Model).ConfigurationFQN(model.id)
        do ..Require(##class(App.Governance.MCPServer).Create({"name":"delete-server","endpointUrl":"http://localhost:8082/mcp","status":"approved"},.server))
        set tool=##class(App.Governance.Tool).%New(),tool.Name="delete-tool",tool.ClassName="App.AIHub.Tool.RemoteMCP",tool.MethodName="delete-fixture"
        set tool.MCPServerName="delete-server",tool.RemoteToolName="fixture",tool.DescriptorJSON="{}"
        do ..Require(tool.%Save())
        do ..Require(##class(App.Governance.Agent).Create({"name":"delete-child","modelName":"delete-model","tools":["delete-tool"],"status":"approved"},.child))
        do ..Require(##class(App.Governance.Agent).Create({"name":"delete-parent","modelName":"delete-model","delegates":["delete-child"],"status":"approved"},.parent))
        set sc=##class(App.Governance.Deletion).Execute("model","delete-model",.ignored,.code)
        do ..Check($$$ISERR(sc)&&(code=409),"model blocked while any agents reference it")
        do ..Check(##class(%ConfigStore.Configuration).Exists(fqn),"blocked deletion preserves connection details")
        set sc=##class(App.Governance.Deletion).Execute("mcp-server","delete-server",.ignored,.code)
        do ..Check($$$ISERR(sc)&&(code=409),"server blocked while a tool is assigned")
        do ..Check(##class(App.Governance.Tool).ListJSON("delete-server").%Size()=1,"blocked server deletion preserves tools")
        set sc=##class(App.Governance.Deletion).Execute("agent","delete-child",.ignored,.code)
        do ..Check($$$ISERR(sc)&&(code=409),"referenced delegate cannot be deleted")
        // Production settings are also references to registered agents.
        set production=##class(Ens.Config.Production).%New(),production.Name="App.Test.DeleteProduction"
        set item=##class(Ens.Config.Item).%New(),item.Name="Configured agent",item.ClassName="App.Interop.AgentOperation"
        set setting=##class(Ens.Config.Setting).%New(),setting.Name="AgentName",setting.Target="Host",setting.Value="delete-parent"
        do item.Settings.Insert(setting),production.Items.Insert(item)
        do ..Require(production.%Save())
        set sc=##class(App.Governance.Deletion).Execute("agent","delete-parent",.ignored,.code)
        do ..Check($$$ISERR(sc)&&(code=409),"BPL production dependency blocks deletion")
        do ..Require(##class(Ens.Config.Production).%DeleteId(production.%Id()))
        set history=##class(App.Governance.ChatConversation).%New(),history.ConversationId="delete-history",history.AgentName="delete-parent",history.Username="fixture",history.SessionId=123
        do ..Require(history.%Save())
        set permission=##class(App.Governance.AgentUser).%New(),permission.Username="fixture",permission.AgentName="delete-parent"
        do ..Require(permission.%Save())
        do ..Require(##class(App.Governance.Deletion).Execute("agent","delete-parent",.ignored,.code))
        do ..Check(##class(App.Governance.AgentDelegate).ListForAgent("delete-parent").%Size()=0,"outgoing delegate assignments removed")
        do ..Check(##class(App.Governance.AgentUser).ListForUser("fixture").%Size()=0,"user assignments removed")
        do ..Check(##class(App.Governance.ChatConversation).%ExistsId(history.%Id()),"historical conversations preserved")
        do ..Require(##class(App.Governance.Deletion).Execute("agent","delete-child",.ignored,.code))
        do ..Check(##class(App.Governance.AgentTool).ListForAgent("delete-child").%Size()=0,"tool assignments removed")
        do ..Require(##class(App.Governance.Deletion).Execute("mcp-server","delete-server",.ignored,.code))
        do ..Check(##class(App.Governance.Tool).ListJSON("delete-server").%Size()=0,"unassigned discovered tools removed with server")
        do ..Require(##class(App.Governance.Deletion).Execute("model","delete-model",.ignored,.code))
        do ..Check('##class(%ConfigStore.Configuration).Exists(fqn),"deleted model connection removed")
        set sc=##class(App.Governance.Deletion).Execute("model","delete-model",.ignored,.code)
        do ..Check($$$ISERR(sc)&&(code=404),"unknown resource returns not found")
    } catch exception {
        set ..Failures=..Failures+1
        write "EXCEPTION ",$SYSTEM.Status.GetErrorText(exception.AsStatus()),!
    }
    write "DELETION_FAILURES=",..Failures,!
    return ..Failures
}
}
