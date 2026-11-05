Include %occStatus

/// Runtime tool bound to one explicitly assigned registered agent.
Class App.AIHub.Tool.DelegateAgent Extends %AI.Tool
{

Property SourceAgent As %String [ Internal ];
Property TargetAgent As %String [ Internal ];
Property ToolName As %String [ Internal ];
Property Descriptor As %DynamicObject [ Internal ];

ClassMethod Create(source As %String, target As %String,
    Output tool As App.AIHub.Tool.DelegateAgent) As %Status
{
    if '##class(App.Governance.AgentDelegate).IsAllowed(source, target) {
        return $$$ERROR($$$GeneralError, "Agent is not available for delegation: " _ target)
    }
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name, DisplayName FROM App_Governance.Agent WHERE Name = ?", target)
    if 'rs.%Next() return $$$ERROR($$$GeneralError, "Delegate does not exist")
    set tool = ..%New()
    set tool.SourceAgent = source, tool.TargetAgent = rs.%Get("Name")
    set tool.ToolName = "delegate_agent_" _ rs.%Get("ID")
    set tool.Descriptor = {
        "name":(tool.ToolName),
        "description":("Delegate a task to agent " _ rs.%Get("DisplayName") _ " (" _ tool.TargetAgent _ "). Uses its own model, instructions and tools. Returns its answer."),
        "source":"iris", "provider":"App.AIHub.Tool.DelegateAgent", "stateful":true, "requires_auth":false,
        "parameters":{"type":"object", "properties":{"prompt":{"type":"string", "description":"Task and all context needed by the specialist agent"}}, "required":["prompt"], "additionalProperties":false},
        "returns":{"type":"object"}
    }
    return $$$OK
}

Method %Discover() As %DynamicObject
{
    return {"tools":[(..Descriptor)]}
}

Method %Invoke(toolName As %String, args As %DynamicObject) As %Any
{
    set source = ##class(App.AIHub.RuntimeContext).GetAgent()
    if (toolName '= ..ToolName) || (source '= ..SourceAgent) {
        return ..%ToolError($$$ERROR($$$GeneralError, "Delegation tool does not belong to this agent"))
    }
    set username = ##class(App.AIHub.RuntimeContext).GetUsername()
    set sc = ##class(App.AIHub.Policy.UserAccess).Check(username, source)
    if $$$ISERR(sc) return ..%ToolError(sc)
    if '##class(App.Governance.AgentDelegate).IsAllowed(source, ..TargetAgent) {
        return ..%ToolError($$$ERROR($$$GeneralError, "Agent delegation is no longer allowed"))
    }
    set sc = ##class(App.AIHub.Policy.UserAccess).Check(username, ..TargetAgent)
    if $$$ISERR(sc) return ..%ToolError(sc)
    if '$isobject(args) return ..%ToolError($$$ERROR($$$GeneralError, "Delegation arguments are required"))
    if args.%GetTypeOf("prompt") '= "string" return ..%ToolError($$$ERROR($$$GeneralError, "Delegation prompt must be a string"))
    set prompt = args.%Get("prompt")
    if $zstrip(prompt, "<>W") = "" return ..%ToolError($$$ERROR($$$GeneralError, "Delegation prompt cannot be empty"))

    set snapshot = ##class(App.AIHub.RuntimeContext).Snapshot()
    set sc = ##class(App.AIHub.RuntimeContext).EnterDelegate(..TargetAgent)
    if $$$ISERR(sc) return ..%ToolError(sc)
    try {
        // Each delegation has its own conversation, model and policies. The
        // caller's conversation is never shared with the specialist implicitly.
        set sc = ##class(App.AIHub.Delegation).Send(..TargetAgent, prompt, .result)
    } catch exception {
        set sc = exception.AsStatus()
    }
    do ##class(App.AIHub.RuntimeContext).Restore(snapshot)
    if $$$ISERR(sc) return ..%ToolError(sc)
    return {"agentName":(..TargetAgent), "conversationId":(result.%Get("conversationId")),
        "content":(result.%Get("content")), "requestId":(result.%Get("requestId"))}
}

}
