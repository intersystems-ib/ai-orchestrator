Include %occStatus

/// Internal adapter that exposes one selected method from a native %AI.Tool.
/// This preserves method-level agent allow-lists even when one class publishes
/// several tools and ToolManager.AddTool() registers an entire instance.
Class App.AIHub.Tool.SelectedMethod Extends %AI.Tool
{

Property Target As %AI.Tool [ Internal ];
Property Descriptor As %DynamicObject [ Internal ];
Property ToolName As %String [ Internal ];

ClassMethod Create(className As %String, methodName As %String,
    Output tool As App.AIHub.Tool.SelectedMethod) As %Status
{
    if '##class(App.Governance.ClassUtil).IsSubclass(className, "%AI.Tool") {
        quit $$$ERROR($$$GeneralError, "Class does not extend %AI.Tool: " _ className)
    }
    set target = $classmethod(className, "%New")
    if '$isobject(target) quit $$$ERROR($$$GeneralError, "Could not instantiate %AI.Tool class: " _ className)

    set catalog = target.%Discover()
    set descriptors = catalog.%Get("tools")
    if '$isobject(descriptors) quit $$$ERROR($$$GeneralError, className _ " did not return a valid AI Hub catalog")
    set descriptor = ""
    for index = 0:1:(descriptors.%Size() - 1) {
        set candidate = descriptors.%Get(index)
        if candidate.%Get("name", "") = methodName {
            set descriptor = candidate
            quit
        }
    }
    if '$isobject(descriptor) quit $$$ERROR($$$GeneralError, "Method is no longer published by " _ className _ ": " _ methodName)

    set tool = ..%New()
    set tool.Target = target
    set tool.Descriptor = descriptor
    set tool.ToolName = methodName
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
    if toolName '= ..ToolName quit ..%ToolError($$$ERROR($$$GeneralError, "Tool is not assigned to this adapter: " _ toolName))
    quit ..Target.%Invoke(toolName, args)
}

}
