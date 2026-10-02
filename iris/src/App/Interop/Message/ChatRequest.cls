/// Durable interoperability request for every governed LLM invocation.
Class App.Interop.Message.ChatRequest Extends Ens.Request
{

Property RequestId As %String(MAXLEN = 64) [ Required ];
Property AgentName As %String(MAXLEN = 120) [ Required ];
Property Message As %String(MAXLEN = "") [ Required ];
Property ConversationId As %String(MAXLEN = 64);
Property Username As %String(MAXLEN = 128) [ Required ];
Property RequestedAt As %TimeStamp;
Property Purpose As %String(VALUELIST = ",chat,test") [ InitialExpression = "chat" ];

}
