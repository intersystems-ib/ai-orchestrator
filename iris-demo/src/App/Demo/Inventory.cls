Include %occStatus

Class App.Demo.Inventory Extends %Persistent
{

Property Sku As %String;
Property Name As %String;
Property Stock As %Integer;

Index SkuIndex On Sku [ Unique ];
Index NameSearchIndex On (Name) As %iFind.Index.Basic(
    INDEXOPTION = 1, LANGUAGE = "en", LOWER = 1);

/// Creates the sample catalog without overwriting existing inventory rows.
ClassMethod SeedDemo(Output created As %Integer) As %Status
{
    set created = 0
    set products = [
        {"sku":"INV-001","name":"Premium ground coffee","stock":48},
        {"sku":"INV-002","name":"Organic green tea","stock":35},
        {"sku":"INV-003","name":"85% dark chocolate","stock":62},
        {"sku":"INV-004","name":"Oat cookies","stock":27},
        {"sku":"INV-005","name":"Extra virgin olive oil","stock":41},
        {"sku":"INV-006","name":"Brown rice","stock":73},
        {"sku":"INV-007","name":"Artisan pasta","stock":54},
        {"sku":"INV-008","name":"Homemade tomato sauce","stock":29},
        {"sku":"INV-009","name":"Mountain honey","stock":18},
        {"sku":"INV-010","name":"Strawberry jam","stock":24},
        {"sku":"INV-011","name":"Almond milk","stock":46},
        {"sku":"INV-012","name":"Whole grain cereal","stock":39},
        {"sku":"INV-013","name":"Organic wheat flour","stock":31},
        {"sku":"INV-014","name":"Cooked chickpeas","stock":67},
        {"sku":"INV-015","name":"Tuna in olive oil","stock":52},
        {"sku":"INV-016","name":"Peanut butter","stock":22},
        {"sku":"INV-017","name":"Mixed nuts","stock":44},
        {"sku":"INV-018","name":"Natural mineral water","stock":96},
        {"sku":"INV-019","name":"Orange juice","stock":38},
        {"sku":"INV-020","name":"Decaffeinated coffee beans","stock":26}
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
