/// Native AI Hub tools for querying demo shipments.
Class App.Demo.ShipmentTools Extends %AI.Tool
{

/// Consulta los envíos que contienen un producto concreto de Inventory.
Method SearchShipmentsByProduct(productId As %Integer(DESCRIPTION = "Identificador ID del producto en App.Demo.Inventory")) As %DynamicObject
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
    quit ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 50, startedAt)
}

/// Extrae envíos por fecha de envío. Cualquiera de los dos límites puede omitirse.
Method SearchShipmentsByDateRange(
    startDate As %String(DESCRIPTION = "Fecha inicial inclusiva en formato YYYY-MM-DD; dejar vacía si no hay límite inferior") = "",
    endDate As %String(DESCRIPTION = "Fecha final inclusiva en formato YYYY-MM-DD; dejar vacía si no hay límite superior") = "") As %DynamicObject
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
    quit ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 100, startedAt)
}

}
