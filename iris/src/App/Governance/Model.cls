Class App.Governance.Model Extends (%Persistent, %JSON.Adaptor)
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property Provider As %String(MAXLEN = 40) [ Required ];
Property ModelId As %String(MAXLEN = 200) [ Required ];
/// Fully qualified Config Store reference, for example AI.LLM.OpenAI.Production.
Property ConfigName As %String(MAXLEN = 240);
Property Status As %String(VALUELIST = ",draft,approved,suspended,retired") [ InitialExpression = "draft" ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property CreatedAt As %TimeStamp;

Index NameIndex On Name [ Unique ];

ClassMethod Create(payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set name = payload.%Get("name", "")
    set provider = payload.%Get("provider", "")
    set modelId = payload.%Get("modelId", "")
    if (name = "") || (provider = "") || (modelId = "") {
        quit $$$ERROR($$$GeneralError, "name, provider and modelId are required")
    }
    if '##class(App.Governance.Catalog).IsProviderSupported(provider) {
        quit $$$ERROR($$$GeneralError, "Unsupported AI Hub provider: " _ provider)
    }

    set model = ..%New()
    set model.Name = name
    set model.DisplayName = payload.%Get("displayName", name)
    set model.Provider = provider
    set model.ModelId = modelId
    set model.ConfigName = payload.%Get("configName", "")
    set model.Status = payload.%Get("status", "draft")
    set model.Enabled = payload.%Get("enabled", 1)
    set model.CreatedAt = $ZDATETIME($HOROLOG, 3)
    set sc = model.%Save()
    if $$$ISERR(sc) quit sc

    set result = model.%JSONExportToString(.json)
    set result = {}.%FromJSON(json)
    quit $$$OK
}

ClassMethod ListJSON() As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name, DisplayName, Provider, ModelId, ConfigName, Status, Enabled, CreatedAt " _
        "FROM App_Governance.Model ORDER BY Name")
    while rs.%Next() {
        do output.%Push({
            "id":(rs.%Get("ID")),
            "name":(rs.%Get("Name")),
            "displayName":(rs.%Get("DisplayName")),
            "provider":(rs.%Get("Provider")),
            "modelId":(rs.%Get("ModelId")),
            "configName":(rs.%Get("ConfigName")),
            "status":(rs.%Get("Status")),
            "enabled":(rs.%Get("Enabled")),
            "createdAt":(rs.%Get("CreatedAt"))
        })
    }
    quit output
}

}

