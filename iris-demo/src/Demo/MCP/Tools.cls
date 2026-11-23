/// Explicitly publish the four business methods, including their input schemas.
Class Demo.MCP.Tools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="BusinessExamples">
  <Description>Inventory and shipment operations</Description>
  <Include Class="App.Demo.InventoryTools" Tool="SearchInventory"/>
  <Include Class="App.Demo.InventoryTools" Tool="AddInventoryItem"/>
  <Include Class="App.Demo.ShipmentTools" Tool="SearchShipmentsByProduct"/>
  <Include Class="App.Demo.ShipmentTools" Tool="SearchShipmentsByDateRange"/>
</ToolSet>
}
}
