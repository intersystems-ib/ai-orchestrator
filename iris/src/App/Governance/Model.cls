Class App.Governance.Model Extends (%Persistent, %JSON.Adaptor)
{

Property Name As %String(MAXLEN = 120) [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property Provider As %String(MAXLEN = 40) [ Required ];
Property ModelId As %String(MAXLEN = 200) [ Required ];

Property Status As %String(VALUELIST = ",draft,approved,suspended,retired") [ InitialExpression = "draft" ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property CreatedAt As %TimeStamp;

/// Declared serving capacity; changing it does not reconfigure the provider.
Property MaxContextTokens As %Integer(MINVAL = 512) [ InitialExpression = 4096 ];

Index NameIndex On Name [ Unique ];

ClassMethod Create(payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set name = payload.%Get("name", "")
    set provider = payload.%Get("provider", "")
    set modelId = payload.%Get("modelId", "")
    if (name = "") || (provider = "") || (modelId = "") {
        return $$$ERROR($$$GeneralError, "name, provider and modelId are required")
    }
    if '##class(App.Governance.Catalog).IsProviderSupported(provider) {
        return $$$ERROR($$$GeneralError, "Unsupported AI Hub provider: " _ provider)
    }
    set sc = ..ValidateSecrets(payload.%Get("apiKey", ""), payload.%Get("bearerToken", ""))
    if $$$ISERR(sc) return sc

    set capacity = payload.%Get("maxContextTokens", 4096)
    set sc = ##class(App.AIHub.ContextBudget).ValidateCapacity(capacity)
    if $$$ISERR(sc) return sc

    set model = ..%New()
    set model.MaxContextTokens = capacity
    set model.Name = name
    set model.DisplayName = payload.%Get("displayName", name)
    set model.Provider = provider
    set model.ModelId = modelId
    set model.Status = payload.%Get("status", "draft")
    set model.Enabled = payload.%Get("enabled", 1)
    set model.CreatedAt = $zdatetime($horolog, 3)

    tstart
    set sc = model.%Save()
    if $$$ISERR(sc) { trollback  return sc }
    set sc = ..SaveConfiguration(model, ..DetailsFromPayload(payload))
    if $$$ISERR(sc) { trollback  return sc }
    tcommit
    set result = ..OneJSON(model)
    return $$$OK
}

ClassMethod Update(name As %String, payload As %DynamicObject,
    Output result As %DynamicObject) As %Status
{
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.Model WHERE Name = ?", name)
    if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if 'rs.%Next() return $$$ERROR($$$GeneralError, "Model does not exist: " _ name)
    set model = ..%OpenId(rs.%Get("ID"))

    set provider = payload.%Get("provider", model.Provider)
    set modelId = payload.%Get("modelId", model.ModelId)
    if (provider = "") || (modelId = "") {
        return $$$ERROR($$$GeneralError, "provider and modelId are required")
    }
    if '##class(App.Governance.Catalog).IsProviderSupported(provider) {
        return $$$ERROR($$$GeneralError, "Unsupported AI Hub provider: " _ provider)
    }
    set sc = ..ValidateSecrets(payload.%Get("apiKey", ""), payload.%Get("bearerToken", ""))
    if $$$ISERR(sc) return sc

    set sc = ..GetConnectionDetails(model.%Id(), .previousDetails, 0)
    if $$$ISERR(sc) return sc
    set capacity = payload.%Get("maxContextTokens", model.MaxContextTokens)
    set sc = ##class(App.AIHub.ContextBudget).ValidateCapacity(capacity, name)
    if $$$ISERR(sc) return sc
    set model.MaxContextTokens = capacity
    set model.DisplayName = payload.%Get("displayName", model.DisplayName)
    set model.Provider = provider
    set model.ModelId = modelId
    set model.Status = payload.%Get("status", model.Status)
    set model.Enabled = payload.%Get("enabled", model.Enabled)

    tstart
    set sc = model.%Save()
    if $$$ISERR(sc) { trollback  return sc }
    set sc = ..SaveConfiguration(model, ..DetailsFromPayload(payload, previousDetails))
    if $$$ISERR(sc) { trollback  return sc }
    tcommit
    set result = ..OneJSON(model)
    return $$$OK
}

ClassMethod DetailsFromPayload(payload As %DynamicObject, previous As %DynamicObject = "") As %DynamicObject [ Internal, Private ]
{
    set details = {}
    if $isobject(previous) set details = {}.%FromJSON(previous.%ToJSON())
    do ..PayloadDetail(details, payload, "apiKey", "api_key")
    do ..PayloadDetail(details, payload, "baseUrl", "base_url")
    do ..PayloadDetail(details, payload, "orgId", "org_id")
    do ..PayloadDetail(details, payload, "version", "version")
    do ..PayloadDetail(details, payload, "region", "region")
    do ..PayloadDetail(details, payload, "bearerToken", "bearer_token")
    do ..PayloadDetail(details, payload, "projectId", "project_id")
    do ..PayloadDetail(details, payload, "serviceAccountPath", "service_account_path")
    do ..PayloadDetail(details, payload, "siteUrl", "site_url")
    do ..PayloadDetail(details, payload, "siteName", "site_name")
    return details
}

ClassMethod PayloadDetail(details As %DynamicObject, payload As %DynamicObject,
    field As %String, key As %String) [ Internal, Private ]
{
    if 'payload.%IsDefined(field) return
    set value = payload.%Get(field)
    if value = "" { do details.%Remove(key) } else { do details.%Set(key, value) }
}

ClassMethod SaveConfiguration(model As App.Governance.Model,
    details As %DynamicObject) As %Status [ Internal, Private ]
{
    set fqn = ..ConfigurationFQN(model.%Id())
    if ##class(%ConfigStore.Configuration).Exists(fqn) {
        set sc = ##class(%ConfigStore.Configuration).Get(fqn, .configuration)
        if $$$ISERR(sc) return sc
        set configuration.Details = details
        set configuration.DisplayName = model.DisplayName
        set configuration.Description = "AI Hub model connection"
        set configuration.Enabled = model.Enabled
        return configuration.SaveChange()
    }
    return ##class(%ConfigStore.Configuration).Create(
        "APP", "AI", "MODEL", "model-" _ model.%Id(), details,
        model.DisplayName, "AI Hub model connection", "", "", model.Enabled)
}

ClassMethod ConfigurationFQN(modelId As %Integer) As %String
{
    return ##class(%ConfigStore.Configuration).BuildFQN(
        "APP", "AI", "MODEL", "model-" _ modelId)
}

ClassMethod GetConnectionDetails(modelId As %Integer,
    Output details As %DynamicObject, resolveSecrets As %Boolean = 0) As %Status
{
    return ##class(%ConfigStore.Configuration).GetDetails(
        ..ConfigurationFQN(modelId), .details, 0, resolveSecrets)
}

ClassMethod ValidateSecrets(apiKey As %String, bearerToken As %String) As %Status [ Internal, Private ]
{
    set sc = ..ValidateSecret(apiKey, "apiKey")
    if $$$ISERR(sc) return sc
    return ..ValidateSecret(bearerToken, "bearerToken")
}

ClassMethod ValidateSecret(value As %String, field As %String) As %Status [ Internal, Private ]
{
    if (value = "") || (value = "not-needed") return $$$OK
    if $extract(value, 1, 9) '= "secret://" {
        return $$$ERROR($$$GeneralError, field _ " must be a secret:// Secure Wallet reference")
    }
    return $$$OK
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
    return output
}

ClassMethod OneJSON(model As App.Governance.Model) As %DynamicObject [ Internal, Private ]
{
    set details = {}
    set sc = ..GetConnectionDetails(model.%Id(), .storedDetails, 0)
    if $$$ISOK(sc), $isobject(storedDetails) set details = storedDetails
    return {
        "id":(model.%Id()), "name":(model.Name),
        "displayName":(model.DisplayName), "provider":(model.Provider),
        "maxContextTokens":(+model.MaxContextTokens), "modelId":(model.ModelId), "apiKey":(details.%Get("api_key", "")),
        "baseUrl":(details.%Get("base_url", "")), "orgId":(details.%Get("org_id", "")),
        "version":(details.%Get("version", "")), "region":(details.%Get("region", "")),
        "bearerToken":(details.%Get("bearer_token", "")),
        "projectId":(details.%Get("project_id", "")),
        "serviceAccountPath":(details.%Get("service_account_path", "")),
        "siteUrl":(details.%Get("site_url", "")),
        "siteName":(details.%Get("site_name", "")),
        "status":(model.Status), "enabled":(model.Enabled),
        "createdAt":(model.CreatedAt)
    }
}

}
