/// Detailed product line included in a shipment.
Class App.Demo.ShipmentProduct Extends %Persistent
{

Property Shipment As App.Demo.Shipment [ Required ];
Property Product As App.Demo.Inventory [ Required ];
Property Quantity As %Integer(MINVAL = 1) [ Required ];
Property TotalCost As %Numeric(SCALE = 2) [ Required ];

Index ShipmentProductIndex On (Shipment, Product) [ Unique ];
Index ProductIndex On Product;

}
