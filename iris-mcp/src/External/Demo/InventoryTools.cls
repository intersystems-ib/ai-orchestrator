/// Inventory price tools for the independent MCP server.
Include %occStatus

Class External.Demo.InventoryTools Extends %AI.Tool
{

/// Get daily prices for every product matched by iFind.
Method GetDailyPrices(
    name As %String(DESCRIPTION = "Product name words; English iFind search"),
    day As %String(DESCRIPTION = "Quotation date in YYYY-MM-DD format")
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
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'en') AND Day = ? ORDER BY Name",
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
    return {"name":(name), "day":(day), "prices":(prices), "count":(prices.%Size())}
}

/// Find product names with daily prices using the iFind index.
Method SearchInventory(name As %String(DESCRIPTION = "Words to match in the product name")) As %DynamicObject
{
    set startedAt = $zhorolog
    set resultSet = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT DISTINCT Name FROM External_Demo.Price " _
        "WHERE %ID %FIND search_index(NameSearchIndex, ?, 1, 'en') " _
        "ORDER BY Name", name)
    return ##class(%AI.Tools.SQL).FormatResultSet(resultSet, 25, startedAt)
}

}

