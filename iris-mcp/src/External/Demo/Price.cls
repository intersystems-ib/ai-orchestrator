Include %occStatus

/// Standalone daily product quotations for the external MCP demo.
Class External.Demo.Price Extends %Persistent
{
Property Name As %String [ Required ];
Property Day As %Date [ Required ];
Property Price As %Numeric(MINVAL = 0, SCALE = 2) [ Required ];
Property Currency As %String(VALUELIST = ",EUR") [ InitialExpression = "EUR", Required ];

Index NameDay On (Name, Day) [ Unique ];
Index NameSearchIndex On (Name) As %iFind.Index.Basic(
    INDEXOPTION = 1, LANGUAGE = "en", LOWER = 1);

/// Creates seven days of synthetic EUR quotations without overwriting prices.
ClassMethod SeedDemo() As %Status
{
    set products = ["Premium ground coffee","Organic green tea","85% dark chocolate","Oat cookies","Extra virgin olive oil","Brown rice","Artisan pasta","Homemade tomato sauce","Mountain honey","Strawberry jam","Almond milk","Whole grain cereal","Organic wheat flour","Cooked chickpeas","Tuna in olive oil","Peanut butter","Mixed nuts","Natural mineral water","Orange juice","Decaffeinated coffee beans"]
    for index = 0:1:(products.%Size()-1) {
        set name = products.%Get(index)
        for offset = 0:1:6 {
            set day = +$horolog - offset
            set existing = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT ID FROM External_Demo.Price WHERE Name = ? AND Day = ?", name, day)
            if existing.%SQLCODE < 0 return $$$ERROR($$$SQLError, existing.%SQLCODE, existing.%Message)
            if existing.%Next() continue
            set quotation = ..%New()
            set quotation.Name = name, quotation.Day = day
            set quotation.Price = 2 + ((index + 1) * .75) + (offset * .10)
            set sc = quotation.%Save()
            if $$$ISERR(sc) return sc
        }
    }
    return $$$OK
}
}
