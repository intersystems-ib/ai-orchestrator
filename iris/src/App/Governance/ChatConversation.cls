Include %occStatus

/// Ownership and persisted AI Hub session for a governed chat.
Class App.Governance.ChatConversation Extends %Persistent
{

Property ConversationId As %String(MAXLEN = 64) [ Required ];
Property AgentName As %String(MAXLEN = 120) [ Required ];
Property Username As %String(MAXLEN = 128) [ Required ];
Property SessionId As %Integer [ Required ];
Property CreatedAt As %TimeStamp;
Property UpdatedAt As %TimeStamp;

Index ConversationIndex On ConversationId [ Unique ];

}
