Include %occStatus

/// Governed reference to a compiled AI Hub policy class.
Class App.Governance.Policy Extends (%Persistent, %JSON.Adaptor)
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property ClassName As %String(MAXLEN = 240) [ Required ];
Property Type As %String(VALUELIST = ",authorization,audit,discovery") [ Required ];
Property Description As %String(MAXLEN = 1000);
Property Status As %String(VALUELIST = ",draft,approved,suspended,retired") [ InitialExpression = "draft" ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property CreatedAt As %TimeStamp;

Index NameIndex On Name [ Unique ];
Index ClassTypeIndex On (ClassName, Type) [ Unique ];

ClassMethod Create(payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set name = payload.%Get("name", "")
    set className = payload.%Get("className", "")
    set type = payload.%Get("type", "")
    if '##class(App.Governance.ClassUtil).ValidName(name) {
        quit $$$ERROR($$$GeneralError, "name is required and cannot contain commas")
    }
    if className = "" quit $$$ERROR($$$GeneralError, "className is required")
    set baseClass = ..BaseClass(type)
    if baseClass = "" quit $$$ERROR($$$GeneralError, "type must be authorization, audit or discovery")
    if '##class(App.Governance.ClassUtil).IsSubclass(className, baseClass) {
        quit $$$ERROR($$$GeneralError, "The class is not compiled or does not extend " _ baseClass)
    }

    set item = ..%New()
    set item.Name = name
    set item.DisplayName = payload.%Get("displayName", name)
    set item.ClassName = className
    set item.Type = type
    set item.Description = payload.%Get("description", "")
    set item.Status = payload.%Get("status", "draft")
    set item.Enabled = payload.%Get("enabled", 1)
    set item.CreatedAt = $zdatetime($horolog, 3)
    set sc = item.%Save()
    if $$$ISERR(sc) quit sc
    set ignored = item.%JSONExportToString(.json)
    set result = {}.%FromJSON(json)
    quit $$$OK
}

ClassMethod BaseClass(type As %String) As %String
{
    if type = "authorization" quit "%AI.Policy.Authorization"
    if type = "audit" quit "%AI.Policy.Audit"
    if type = "discovery" quit "%AI.Policy.Discovery"
    quit ""
}

ClassMethod ListJSON() As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name, DisplayName, ClassName, Type, Description, Status, Enabled, CreatedAt " _
        "FROM App_Governance.Policy ORDER BY Type, Name")
    while rs.%Next() {
        do output.%Push({
            "id":(rs.%Get("ID")), "name":(rs.%Get("Name")),
            "displayName":(rs.%Get("DisplayName")), "className":(rs.%Get("ClassName")),
            "type":(rs.%Get("Type")), "description":(rs.%Get("Description")),
            "status":(rs.%Get("Status")), "enabled":(rs.%Get("Enabled")),
            "createdAt":(rs.%Get("CreatedAt"))
        })
    }
    quit output
}

}
