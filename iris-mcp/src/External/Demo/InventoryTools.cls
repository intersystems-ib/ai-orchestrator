/// Inventory price tools for the independent MCP server.
Include %occStatus

Class External.Demo.InventoryTools Extends %AI.Tool
{

/// Cotizaciones del día indicado para todos los productos encontrados por iFind.
Method GetDailyPrices(
    name As %String(DESCRIPTION = "Palabras del nombre del producto; búsqueda iFind en español"),
    day As %String(DESCRIPTION = "Día de la cotización en formato YYYY-MM-DD")
) As %DynamicObject
{
    set name = $zstrip(name, "<>W")
    if name = "" {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$GeneralError, "Product name is required"))
    }
    set valid = 0, logicalDay = ""
    try {
        if day ? 4N1"-"2N1"-"2N {
            set logicalDay = $zdateh(day, 3)
            set valid = ($zdate(logicalDay, 3) = day)
        }
    } catch exception {
        set valid = 0
    }
    if 'valid {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$GeneralError, "Quotation day must be a valid date in YYYY-MM-DD format"))
    }
    // Explicitly uses the same Spanish iFind index as App.Demo.Inventory.
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Name, Price, Currency FROM External_Demo.Price " _
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'es') AND Day = ? ORDER BY Name",
        name, logicalDay)
    if rs.%SQLCODE < 0 {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message))
    }
    set prices = []
    while rs.%Next() {
        do prices.%Push({"id":(rs.%Get("ID")),
            "name":(rs.%Get("Name")), "day":(day),
            "price":(rs.%Get("Price")), "currency":(rs.%Get("Currency"))})
    }
    quit {"name":(name), "day":(day), "prices":(prices), "count":(prices.%Size())}
}

/// Busca nombres de productos con cotizaciones mediante el índice iFind.
Method SearchInventory(name As %String(DESCRIPTION = "Palabras que debe contener el nombre del producto")) As %DynamicObject
{
    set startedAt = $zhorolog
    set resultSet = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT DISTINCT Name FROM External_Demo.Price " _
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'es') " _
        "ORDER BY Name", name)
    quit ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 25, startedAt)
}

}

