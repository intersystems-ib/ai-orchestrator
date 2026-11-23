/// Native AI Hub tools for querying demo shipments.
Class App.Demo.ShipmentTools Extends %AI.Tool
{

/// Find shipments containing a specific inventory product.
Method SearchShipmentsByProduct(productId As %Integer(DESCRIPTION = "Product ID in App.Demo.Inventory")) As %DynamicObject
{
    set startedAt = $zhorolog
    set resultSet = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT s.ID AS ShipmentId, s.ShipmentReference, s.ShipmentDate, " _
        "s.ReceptionDate, s.TotalAmount, s.Customer, i.ID AS ProductId, " _
        "i.Sku, i.Name AS ProductName, sp.Quantity, sp.TotalCost " _
        "FROM App_Demo.Shipment s " _
        "JOIN App_Demo.ShipmentProduct sp ON sp.Shipment = s.ID " _
        "JOIN App_Demo.Inventory i ON i.ID = sp.Product " _
        "WHERE sp.Product = ? ORDER BY s.ShipmentDate, s.ShipmentReference",
        productId)
    return ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 50, startedAt)
}

/// Find shipments by shipping date. Either date limit can be omitted.
Method SearchShipmentsByDateRange(
    startDate As %String(DESCRIPTION = "Inclusive start date in YYYY-MM-DD format; leave empty for no lower limit") = "",
    endDate As %String(DESCRIPTION = "Inclusive end date in YYYY-MM-DD format; leave empty for no upper limit") = "") As %DynamicObject
{
    set startedAt = $zhorolog
    set startValue = ""
    set endValue = ""
    if startDate '= "" set startValue = $zdateh(startDate, 3)
    if endDate '= "" set endValue = $zdateh(endDate, 3)
    set sql = "SELECT s.ID AS ShipmentId, s.ShipmentReference, s.ShipmentDate, " _
        "s.ReceptionDate, s.TotalAmount, s.Customer, i.ID AS ProductId, " _
        "i.Sku, i.Name AS ProductName, sp.Quantity, sp.TotalCost " _
        "FROM App_Demo.Shipment s " _
        "JOIN App_Demo.ShipmentProduct sp ON sp.Shipment = s.ID " _
        "JOIN App_Demo.Inventory i ON i.ID = sp.Product "
    if (startDate '= "") && (endDate '= "") {
        set resultSet = ##class(%SQL.Statement).%ExecDirect(,
            sql _ "WHERE s.ShipmentDate >= ? AND s.ShipmentDate <= ? " _
            "ORDER BY s.ShipmentDate, s.ShipmentReference, i.Name", startValue, endValue)
    } elseif startDate '= "" {
        set resultSet = ##class(%SQL.Statement).%ExecDirect(,
            sql _ "WHERE s.ShipmentDate >= ? " _
            "ORDER BY s.ShipmentDate, s.ShipmentReference, i.Name", startValue)
    } elseif endDate '= "" {
        set resultSet = ##class(%SQL.Statement).%ExecDirect(,
            sql _ "WHERE s.ShipmentDate <= ? " _
            "ORDER BY s.ShipmentDate, s.ShipmentReference, i.Name", endValue)
    } else {
        set resultSet = ##class(%SQL.Statement).%ExecDirect(,
            sql _ "ORDER BY s.ShipmentDate, s.ShipmentReference, i.Name")
    }
    return ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 100, startedAt)
}

}
