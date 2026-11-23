/// Explicit product-name and daily-price tool publication.
Class External.MCP.Tools Extends %AI.ToolSet
{
XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="ExternalIRIS">
  <Description>Product names and daily quotations</Description>
  <Include Class="External.Demo.InventoryTools" Tool="SearchInventory"/>
  <Include Class="External.Demo.InventoryTools" Tool="GetDailyPrices"/>
</ToolSet>
}
}
