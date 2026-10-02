/// Durable interoperability response returned by the governed LLM operation.
Class App.Interop.Message.ChatResponse Extends Ens.Response
{

Property RequestId As %String(MAXLEN = 64) [ Required ];
Property AgentName As %String(MAXLEN = 120);
Property Username As %String(MAXLEN = 128);
Property Success As %Boolean [ InitialExpression = 0 ];
Property HttpStatus As %Integer [ InitialExpression = 502 ];
Property ResultJSON As %String(MAXLEN = "");
Property Error As %String(MAXLEN = "");
Property CompletedAt As %TimeStamp;
Property DurationMs As %Integer;

}
