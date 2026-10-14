/// Inventory tools hosted in the independent external IRIS instance.
Class External.MCP.Tools Extends External.Demo.InventoryTools
{
Property Name As %String [ InitialExpression = "ExternalIRIS" ];
Property Description As %String(MAXLEN = "") [ InitialExpression = "Product names and daily quotations" ];
}
