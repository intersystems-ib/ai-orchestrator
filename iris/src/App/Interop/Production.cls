/// Interoperability production that provides the durable AI governance path.
Class App.Interop.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="App.Interop.Production" LogGeneralTraceEvents="true">
  <Item Name="AI Governance API Service" Category="AI Governance" ClassName="App.Interop.ChatService" PoolSize="1" Enabled="true" Foreground="false" />
  <Item Name="AI Hub LLM Operation" Category="AI Governance" ClassName="App.Interop.LLMOperation" PoolSize="2" Enabled="true" Foreground="false" />
</Production>
}

}
