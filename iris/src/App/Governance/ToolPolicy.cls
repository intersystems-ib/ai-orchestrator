Include %occStatus

/// Legacy storage retained only for the one-time move to agent audit policies.
Class App.Governance.ToolPolicy Extends %Persistent
{

Property ToolName As %String(MAXLEN = 120) [ Required ];
Property PolicyName As %String(MAXLEN = 120) [ Required ];
Property CreatedAt As %TimeStamp;

Index AssignmentIndex On (ToolName, PolicyName) [ Unique ];

}
