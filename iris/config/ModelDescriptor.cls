/// Schema for Orchestrator's existing APP.AI.MODEL connection configurations.
/// Compile in %SYS; provider and model identity remain in App.Governance.Model.
Class App.AIHub.Config.ModelDescriptor Extends ConfigStore.Descriptor
{
Parameter Area = "APP";
Parameter Type = "AI";
Parameter Subtype = "MODEL";
Parameter AllowUnrecognizedDetails = 0;

XData Schema [ MimeType = application/json ]
{
{
    "api_key": {"type":"string","required":false},
    "base_url": {"type":"string","required":false},
    "org_id": {"type":"string","required":false},
    "version": {"type":"string","required":false},
    "region": {"type":"string","required":false},
    "bearer_token": {"type":"string","required":false},
    "project_id": {"type":"string","required":false},
    "service_account_path": {"type":"string","required":false},
    "site_url": {"type":"string","required":false},
    "site_name": {"type":"string","required":false}
}
}
}
