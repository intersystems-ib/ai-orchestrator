/// Native AI Hub tools for the demo inventory.
Class App.Demo.InventoryTools Extends %AI.Tool
{

/// Busca productos mediante el índice full-text iFind del inventario.
Method SearchInventory(name As %String(DESCRIPTION = "Palabras que debe contener el nombre del producto")) As %DynamicObject
{
    set startedAt = $zhorolog
    set resultSet = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Sku, Name, Stock FROM App_Demo.Inventory " _
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'es') " _
        "ORDER BY Name", name)
    quit ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 25, startedAt)
}

}
