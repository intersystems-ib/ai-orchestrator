Include %occStatus

Class App.Demo.Inventory Extends %Persistent
{

Property Sku As %String;
Property Name As %String;
Property Stock As %Integer;

Index SkuIndex On Sku [ Unique ];
Index NameSearchIndex On (Name) As %iFind.Index.Basic(
    INDEXOPTION = 1, LANGUAGE = "es", LOWER = 1);

/// Creates the sample catalog without overwriting existing inventory rows.
ClassMethod SeedDemo(Output created As %Integer) As %Status
{
    set created = 0
    set products = [
        {"sku":"INV-001","name":"Café molido premium","stock":48},
        {"sku":"INV-002","name":"Té verde ecológico","stock":35},
        {"sku":"INV-003","name":"Chocolate negro 85%","stock":62},
        {"sku":"INV-004","name":"Galletas de avena","stock":27},
        {"sku":"INV-005","name":"Aceite de oliva virgen extra","stock":41},
        {"sku":"INV-006","name":"Arroz integral","stock":73},
        {"sku":"INV-007","name":"Pasta artesanal","stock":54},
        {"sku":"INV-008","name":"Salsa de tomate casera","stock":29},
        {"sku":"INV-009","name":"Miel de montaña","stock":18},
        {"sku":"INV-010","name":"Mermelada de fresa","stock":24},
        {"sku":"INV-011","name":"Leche de almendras","stock":46},
        {"sku":"INV-012","name":"Cereales integrales","stock":39},
        {"sku":"INV-013","name":"Harina de trigo ecológica","stock":31},
        {"sku":"INV-014","name":"Garbanzos cocidos","stock":67},
        {"sku":"INV-015","name":"Atún en aceite de oliva","stock":52},
        {"sku":"INV-016","name":"Crema de cacahuete","stock":22},
        {"sku":"INV-017","name":"Frutos secos variados","stock":44},
        {"sku":"INV-018","name":"Agua mineral natural","stock":96},
        {"sku":"INV-019","name":"Zumo de naranja","stock":38},
        {"sku":"INV-020","name":"Café en grano descafeinado","stock":26}
    ]
    for index = 0:1:(products.%Size() - 1) {
        set product = products.%Get(index)
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID FROM App_Demo.Inventory WHERE Sku = ?", product.sku)
        if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
        if rs.%Next() continue
        set item = ..%New()
        set item.Sku = product.sku
        set item.Name = product.name
        set item.Stock = product.stock
        set sc = item.%Save()
        if $$$ISERR(sc) return sc
        set created = created + 1
    }
    return $$$OK
}

}
