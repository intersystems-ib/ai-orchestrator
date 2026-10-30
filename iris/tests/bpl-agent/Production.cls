Class App.Test.BPLProduction Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="App.Test.BPLProduction" LogGeneralTraceEvents="true">
  <Item Name="BPL Service" ClassName="App.Test.BPLService" PoolSize="1" Enabled="true" />
  <Item Name="BPL Process" ClassName="App.Test.BPLProcess" PoolSize="1" Enabled="true" />
  <Item Name="BPL Agent" ClassName="App.Interop.AgentOperation" PoolSize="1" Enabled="true">
    <Setting Target="Host" Name="AgentName">bpl-agent-test</Setting>
  </Item>
</Production>
}
}
