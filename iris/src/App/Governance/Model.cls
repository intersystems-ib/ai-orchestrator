Class App.Governance.Model Extends (%Persistent, %JSON.Adaptor)
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property Provider As %String(MAXLEN = 40) [ Required ];
Property ModelId As %String(MAXLEN = 200) [ Required ];

/// Typed provider connection fields. Secrets contain Secure Wallet references.
Property ApiKey As %String(MAXLEN = 2048);
Property BaseUrl As %String(MAXLEN = 2048);
Property OrgId As %String(MAXLEN = 240);
Property Version As %String(MAXLEN = 120);
Property Region As %String(MAXLEN = 120);
Property BearerToken As %String(MAXLEN = 2048);
Property ProjectId As %String(MAXLEN = 240);
Property ServiceAccountPath As %String(MAXLEN = 2048);
Property SiteUrl As %String(MAXLEN = 2048);
Property SiteName As %String(MAXLEN = 240);

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
    set sc = ..ValidateSecrets(payload.%Get("apiKey", ""), payload.%Get("bearerToken", ""))
    if $$$ISERR(sc) quit sc

    set model = ..%New()
    set model.Name = name
    set model.DisplayName = payload.%Get("displayName", name)
    set model.Provider = provider
    set model.ModelId = modelId
    do ..SetProviderFields(model, payload)
    set model.Status = payload.%Get("status", "draft")
    set model.Enabled = payload.%Get("enabled", 1)
    set model.CreatedAt = $zdatetime($horolog, 3)
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
    set sc = ..ValidateSecrets(payload.%Get("apiKey", ""), payload.%Get("bearerToken", ""))
    if $$$ISERR(sc) quit sc

    set model.DisplayName = payload.%Get("displayName", model.DisplayName)
    set model.Provider = provider
    set model.ModelId = modelId
    do ..SetProviderFields(model, payload)
    set model.Status = payload.%Get("status", model.Status)
    set model.Enabled = payload.%Get("enabled", model.Enabled)
    set sc = model.%Save()
    if $$$ISERR(sc) quit sc
    set result = ..OneJSON(model)
    quit $$$OK
}

ClassMethod SetProviderFields(model As App.Governance.Model,
    payload As %DynamicObject) [ Internal, Private ]
{
    set model.ApiKey = payload.%Get("apiKey", "")
    set model.BaseUrl = payload.%Get("baseUrl", "")
    set model.OrgId = payload.%Get("orgId", "")
    set model.Version = payload.%Get("version", "")
    set model.Region = payload.%Get("region", "")
    set model.BearerToken = payload.%Get("bearerToken", "")
    set model.ProjectId = payload.%Get("projectId", "")
    set model.ServiceAccountPath = payload.%Get("serviceAccountPath", "")
    set model.SiteUrl = payload.%Get("siteUrl", "")
    set model.SiteName = payload.%Get("siteName", "")
}

ClassMethod ValidateSecrets(apiKey As %String, bearerToken As %String) As %Status [ Internal, Private ]
{
    set sc = ..ValidateSecret(apiKey, "apiKey")
    if $$$ISERR(sc) quit sc
    quit ..ValidateSecret(bearerToken, "bearerToken")
}

ClassMethod ValidateSecret(value As %String, field As %String) As %Status [ Internal, Private ]
{
    if (value = "") || (value = "not-needed") quit $$$OK
    if $extract(value, 1, 9) '= "secret://" {
        quit $$$ERROR($$$GeneralError, field _ " must be a secret:// Secure Wallet reference")
    }
    quit $$$OK
}

ClassMethod ListJSON() As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Model ORDER BY Name")
    while rs.%Next() {
        set model = ..%OpenId(rs.%Get("ID"))
        do output.%Push(..OneJSON(model))
    }
    quit output
}

ClassMethod OneJSON(model As App.Governance.Model) As %DynamicObject [ Internal, Private ]
{
    quit {
        "id":(model.%Id()), "name":(model.Name),
        "displayName":(model.DisplayName), "provider":(model.Provider),
        "modelId":(model.ModelId), "apiKey":(model.ApiKey),
        "baseUrl":(model.BaseUrl), "orgId":(model.OrgId),
        "version":(model.Version), "region":(model.Region),
        "bearerToken":(model.BearerToken), "projectId":(model.ProjectId),
        "serviceAccountPath":(model.ServiceAccountPath),
        "siteUrl":(model.SiteUrl), "siteName":(model.SiteName),
        "status":(model.Status), "enabled":(model.Enabled),
        "createdAt":(model.CreatedAt)
    }
}

}
