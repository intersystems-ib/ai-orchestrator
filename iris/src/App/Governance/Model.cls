Class App.Governance.Model Extends (%Persistent, %JSON.Adaptor)
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property Provider As %String(MAXLEN = 40) [ Required ];
Property ModelId As %String(MAXLEN = 200) [ Required ];
/// Provider connection details. Secret values must be Secure Wallet references.
Property Configuration As %String(MAXLEN = "");
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
    set configuration = payload.%Get("configuration", {})
    if '$isobject(configuration) {
        quit $$$ERROR($$$GeneralError, "configuration must be a JSON object")
    }
    do configuration.%Set("model_provider", provider)
    do configuration.%Set("model", modelId)
    set sc = ..ValidateSecrets(configuration)
    if $$$ISERR(sc) quit sc

    set model = ..%New()
    set model.Name = name
    set model.DisplayName = payload.%Get("displayName", name)
    set model.Provider = provider
    set model.ModelId = modelId
    set model.Configuration = configuration.%ToJSON()
    set model.Status = payload.%Get("status", "draft")
    set model.Enabled = payload.%Get("enabled", 1)
    set model.CreatedAt = $ZDATETIME($HOROLOG, 3)
    set sc = model.%Save()
    if $$$ISERR(sc) quit sc

    set result = ..OneJSON(model)
    quit $$$OK
}

ClassMethod Update(name As %String, payload As %DynamicObject,
    Output result As %DynamicObject) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Model WHERE Name = ?", name)
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Model does not exist: " _ name)
    set model = ..%OpenId(rs.%Get("ID"))

    set provider = payload.%Get("provider", model.Provider)
    set modelId = payload.%Get("modelId", model.ModelId)
    if (provider = "") || (modelId = "") {
        quit $$$ERROR($$$GeneralError, "provider and modelId are required")
    }
    if '##class(App.Governance.Catalog).IsProviderSupported(provider) {
        quit $$$ERROR($$$GeneralError, "Unsupported AI Hub provider: " _ provider)
    }
    set configuration = payload.%Get("configuration", ..ConfigurationObject(model.Configuration))
    if '$isobject(configuration) {
        quit $$$ERROR($$$GeneralError, "configuration must be a JSON object")
    }
    do configuration.%Set("model_provider", provider)
    do configuration.%Set("model", modelId)
    set sc = ..ValidateSecrets(configuration)
    if $$$ISERR(sc) quit sc

    set model.DisplayName = payload.%Get("displayName", model.DisplayName)
    set model.Provider = provider
    set model.ModelId = modelId
    set model.Configuration = configuration.%ToJSON()
    set model.Status = payload.%Get("status", model.Status)
    set model.Enabled = payload.%Get("enabled", model.Enabled)
    set sc = model.%Save()
    if $$$ISERR(sc) quit sc
    set result = ..OneJSON(model)
    quit $$$OK
}

ClassMethod ValidateSecrets(configuration As %DynamicObject) As %Status [ Internal, Private ]
{
    set sc = $$$OK
    for index = 1:1:2 {
        set key = $piece("api_key,bearer_token", ",", index)
        set value = configuration.%Get(key, "")
        if value = "" continue
        if value = "not-needed" continue
        if $extract(value, 1, 9) '= "secret://" {
            set sc = $$$ERROR($$$GeneralError, key _ " must be a secret:// Secure Wallet reference")
            quit
        }
    }
    quit sc
}

ClassMethod ListJSON() As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name, DisplayName, Provider, ModelId, Configuration, Status, Enabled, CreatedAt " _
        "FROM App_Governance.Model ORDER BY Name")
    while rs.%Next() {
        do output.%Push({
            "id":(rs.%Get("ID")),
            "name":(rs.%Get("Name")),
            "displayName":(rs.%Get("DisplayName")),
            "provider":(rs.%Get("Provider")),
            "modelId":(rs.%Get("ModelId")),
            "configuration":(..ConfigurationObject(rs.%Get("Configuration"))),
            "status":(rs.%Get("Status")),
            "enabled":(rs.%Get("Enabled")),
            "createdAt":(rs.%Get("CreatedAt"))
        })
    }
    quit output
}

ClassMethod ConfigurationObject(value As %String) As %DynamicObject [ Internal, Private ]
{
    set output = {}
    if value = "" quit output
    try {
        set output = {}.%FromJSON(value)
    } catch exception {
        set output = {}
    }
    quit output
}

ClassMethod OneJSON(model As App.Governance.Model) As %DynamicObject [ Internal, Private ]
{
    quit {
        "id":(model.%Id()), "name":(model.Name),
        "displayName":(model.DisplayName), "provider":(model.Provider),
        "modelId":(model.ModelId),
        "configuration":(..ConfigurationObject(model.Configuration)),
        "status":(model.Status), "enabled":(model.Enabled),
        "createdAt":(model.CreatedAt)
    }
}

}

