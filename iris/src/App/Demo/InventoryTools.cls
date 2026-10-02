/// Native AI Hub tools for the demo inventory.
Include %occStatus

Class App.Demo.InventoryTools Extends %AI.Tool
{

/// Añade un producto o incrementa el stock si ya existe el mismo nombre.
Method AddInventoryItem(
    name As %String(DESCRIPTION = "Nombre del producto"),
    sku As %String(DESCRIPTION = "SKU o referencia única del producto"),
    quantity As %Integer(MINVAL = 0, DESCRIPTION = "Cantidad inicial disponible en stock")
) As %DynamicObject
{
    set name = $zstrip(name, "<>W")
    set sku = $zstrip(sku, "<>W")
    if name = "" {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$GeneralError, "Product name is required"))
    }
    if quantity < 0 {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$GeneralError, "Product quantity cannot be negative"))
    }

    set existing = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT TOP 1 ID FROM App_Demo.Inventory WHERE Name = ? ORDER BY ID", name)
    if existing.%SQLCODE < 0 {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$SQLError, existing.%SQLCODE, existing.%Message))
    }
    if existing.%Next() {
        set id = existing.%Get("ID")
        // The persisted SKU is deliberately excluded from the update.
        set update = ##class(%SQL.Statement).%ExecDirect(,
            "UPDATE App_Demo.Inventory SET Stock = Stock + ? WHERE ID = ?",
            quantity, id)
        if update.%SQLCODE < 0 {
            throw ##class(%Exception.StatusException).CreateFromStatus(
                $$$ERROR($$$SQLError, update.%SQLCODE, update.%Message))
        }
        set item = ##class(App.Demo.Inventory).%OpenId(id)
        if '$isobject(item) {
            throw ##class(%Exception.StatusException).CreateFromStatus(
                $$$ERROR($$$GeneralError, "The updated inventory item could not be reopened"))
        }
        quit {
            "id":(item.%Id()),
            "sku":(item.Sku),
            "name":(item.Name),
            "stock":(item.Stock),
            "quantityAdded":(quantity),
            "created":false,
            "updated":true
        }
    }

    if sku = "" {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$GeneralError, "Product SKU or reference is required"))
    }
    set existing = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Demo.Inventory WHERE Sku = ?", sku)
    if existing.%SQLCODE < 0 {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$SQLError, existing.%SQLCODE, existing.%Message))
    }
    if existing.%Next() {
        throw ##class(%Exception.StatusException).CreateFromStatus(
            $$$ERROR($$$GeneralError, "An inventory item already exists with SKU " _ sku))
    }

    set item = ##class(App.Demo.Inventory).%New()
    set item.Name = name
    set item.Sku = sku
    set item.Stock = quantity
    set sc = item.%Save()
    if $$$ISERR(sc) {
        throw ##class(%Exception.StatusException).CreateFromStatus(sc)
    }

    quit {
        "id":(item.%Id()),
        "sku":(item.Sku),
        "name":(item.Name),
        "stock":(item.Stock),
        "quantityAdded":(quantity),
        "created":true,
        "updated":false
    }
}

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
