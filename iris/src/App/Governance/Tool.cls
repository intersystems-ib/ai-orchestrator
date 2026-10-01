Include %occStatus

/// Governed catalog of methods published by native AI Hub %AI.Tool classes.
Class App.Governance.Tool Extends (%Persistent, %JSON.Adaptor)
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property ClassName As %String(MAXLEN = 240) [ Required ];
Property MethodName As %String(MAXLEN = 200) [ Required ];
Property Description As %String(MAXLEN = 1000);
Property RequiresApproval As %Boolean [ InitialExpression = 0 ];
Property DescriptorJSON As %String(MAXLEN = "");
Property Status As %String(VALUELIST = ",draft,approved,suspended,retired") [ InitialExpression = "approved" ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property CreatedAt As %TimeStamp;

Index NameIndex On Name [ Unique ];
Index MethodIndex On (ClassName, MethodName) [ Unique ];

/// Synchronizes the registry with every application class in this namespace
/// that extends %AI.Tool. %Discover() remains the source of truth for which
/// public methods AI Hub actually exposes.
ClassMethod Synchronize(Output result As %DynamicObject) As %Status
{
    kill seen
    set discovered = 0
    set created = 0
    set updated = 0
    set retired = 0
    set classes = 0

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %Dictionary.CompiledClass ORDER BY Name")
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)

    set sc = $$$OK
    while rs.%Next() {
        set className = rs.%Get("Name")
        // System classes are mapped into every namespace but are not owned by
        // the application. App.AIHub.Tool contains runtime adapters, not
        // business tools, and can include compiled remnants after an upgrade.
        if $extract(className) = "%" continue
        if $extract(className, 1, 15) = "App.AIHub.Tool." continue
        if '##class(App.Governance.ClassUtil).IsSubclass(className, "%AI.Tool") continue
        set classes = classes + 1
        set sc = ..SynchronizeClass(className, .seen, .discovered, .created, .updated)
        if $$$ISERR(sc) quit
    }
    if $$$ISERR(sc) quit sc

    set stale = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name FROM App_Governance.Tool WHERE Status <> 'retired' OR Enabled <> 0")
    if stale.%SQLCODE < 0 quit $$$ERROR($$$SQLError, stale.%SQLCODE, stale.%Message)
    while stale.%Next() {
        if $data(seen(stale.%Get("Name"))) continue
        set item = ..%OpenId(stale.%Get("ID"))
        set item.Status = "retired"
        set item.Enabled = 0
        set sc = item.%Save()
        if $$$ISERR(sc) quit
        set retired = retired + 1
    }
    if $$$ISERR(sc) quit sc

    set result = {
        "classes":(classes),
        "methods":(discovered),
        "created":(created),
        "updated":(updated),
        "retired":(retired),
        "tools":(..ListJSON())
    }
    quit $$$OK
}

ClassMethod SynchronizeClass(className As %String, ByRef seen,
    ByRef discovered As %Integer, ByRef created As %Integer,
    ByRef updated As %Integer) As %Status [ Internal, Private ]
{
    set instance = $classmethod(className, "%New")
    if '$isobject(instance) quit $$$ERROR($$$GeneralError, "Could not instantiate %AI.Tool class: " _ className)
    set sc = $$$OK
    try {
        set catalog = instance.%Discover()
    } catch exception {
        set sc = exception.AsStatus()
    }
    if $$$ISERR(sc) quit sc
    set tools = catalog.%Get("tools")
    if '$isobject(tools) quit $$$OK

    for index = 0:1:(tools.%Size() - 1) {
        set descriptor = tools.%Get(index)
        set toolName = descriptor.%Get("name", "")
        if toolName = "" {
            set sc = $$$ERROR($$$GeneralError, className _ " returned a tool without a name")
            quit
        }
        if $data(seen(toolName)) {
            set sc = $$$ERROR($$$GeneralError, "Duplicate AI Hub tool name: " _ toolName)
            quit
        }
        set seen(toolName) = className _ ":" _ toolName
        set discovered = discovered + 1

        set existing = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID, ClassName, MethodName FROM App_Governance.Tool WHERE Name = ?", toolName)
        if existing.%SQLCODE < 0 {
            set sc = $$$ERROR($$$SQLError, existing.%SQLCODE, existing.%Message)
            quit
        }
        if existing.%Next() {
            if (existing.%Get("ClassName") '= className) || (existing.%Get("MethodName") '= toolName) {
                set sc = $$$ERROR($$$GeneralError, "Tool name collision for " _ toolName _ " between " _ existing.%Get("ClassName") _ " and " _ className)
                quit
            }
            set item = ..%OpenId(existing.%Get("ID"))
            set updated = updated + 1
        } else {
            set item = ..%New()
            set item.Name = toolName
            set item.ClassName = className
            set item.MethodName = toolName
            set item.Status = "approved"
            set item.Enabled = 1
            set item.CreatedAt = $zdatetime($horolog, 3)
            set created = created + 1
        }
        set item.Description = descriptor.%Get("description", "")
        set item.RequiresApproval = descriptor.%Get("requires_auth", 0)
        set item.DescriptorJSON = descriptor.%ToJSON()
        set sc = item.%Save()
        if $$$ISERR(sc) quit
    }
    quit sc
}

ClassMethod ListJSON() As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name, ClassName, MethodName, Description, RequiresApproval, " _
        "DescriptorJSON, Status, Enabled, CreatedAt FROM App_Governance.Tool " _
        "WHERE Status <> 'retired' ORDER BY Name")
    while rs.%Next() {
        do output.%Push({
            "id":(rs.%Get("ID")),
            "name":(rs.%Get("Name")),
            "className":(rs.%Get("ClassName")),
            "methodName":(rs.%Get("MethodName")),
            "description":(rs.%Get("Description")),
            "requiresApproval":(rs.%Get("RequiresApproval")),
            "schema":(rs.%Get("DescriptorJSON")),
            "auditPolicies":(##class(App.Governance.ToolPolicy).ListForTool(rs.%Get("Name"))),
            "status":(rs.%Get("Status")),
            "enabled":(rs.%Get("Enabled")),
            "createdAt":(rs.%Get("CreatedAt"))
        })
    }
    quit output
}

ClassMethod Update(name As %String, payload As %DynamicObject,
    Output result As %DynamicObject) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Tool WHERE Name = ?", name)
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Tool does not exist: " _ name)
    set item = ..%OpenId(rs.%Get("ID"))

    if payload.%Get("className", item.ClassName) '= item.ClassName {
        quit $$$ERROR($$$GeneralError, "The discovered tool class cannot be changed")
    }
    if payload.%Get("methodName", item.MethodName) '= item.MethodName {
        quit $$$ERROR($$$GeneralError, "The discovered tool method cannot be changed")
    }
    set policies = payload.%Get("auditPolicies", ##class(App.Governance.ToolPolicy).ListForTool(name))

    tstart
    set item.Description = payload.%Get("description", item.Description)
    set item.RequiresApproval = payload.%Get("requiresApproval", item.RequiresApproval)
    set item.Status = payload.%Get("status", item.Status)
    set item.Enabled = payload.%Get("enabled", item.Enabled)
    set sc = item.%Save()
    if $$$ISERR(sc) { trollback  quit sc }
    set sc = ##class(App.Governance.ToolPolicy).SetForTool(name, policies)
    if $$$ISERR(sc) { trollback  quit sc }
    tcommit
    set result = {
        "id":(item.%Id()), "name":(item.Name),
        "className":(item.ClassName), "methodName":(item.MethodName),
        "description":(item.Description),
        "requiresApproval":(item.RequiresApproval),
        "schema":(item.DescriptorJSON),
        "auditPolicies":(##class(App.Governance.ToolPolicy).ListForTool(item.Name)),
        "status":(item.Status), "enabled":(item.Enabled),
        "createdAt":(item.CreatedAt)
    }
    quit $$$OK
}

}
