Class External.Test.Inventory
{
ClassMethod Run() As %Integer
{
    set failures=0
    tstart
    try {
        set tool=##class(External.Demo.InventoryTools).%New(), day=$zdate(+$horolog,3), word="Coffee"
        set result=tool.GetDailyPrices(word,day)
        if result.count '= 2 { set failures=failures+1 write "FAIL multiple coffee products",! }
        set first=result.prices.%Get(0)
        if (first.day '= day) || (first.currency '= "EUR") { set failures=failures+1 write "FAIL quotation fields",! }
        set older=tool.GetDailyPrices(word,$zdate(+$horolog-1,3))
        if (older.count '= 2) || (older.prices.%Get(0).price = first.price) { set failures=failures+1 write "FAIL daily price isolation",! }
        set empty=tool.GetDailyPrices(word,"2000-01-01")
        if empty.count '= 0 { set failures=failures+1 write "FAIL absent day",! }
        set empty=tool.GetDailyPrices("zzunknownproduct",day)
        if empty.count '= 0 { set failures=failures+1 write "FAIL absent name",! }
        set empty=tool.GetDailyPrices("cof",day)
        if empty.count '= 0 { set failures=failures+1 write "FAIL full-text word matching",! }
        set lower=tool.GetDailyPrices($zconvert(word,"L"),day)
        if lower.count '= 2 { set failures=failures+1 write "FAIL lowercase iFind",! }
        for bad="2026-02-30","14/10/2026","2026-1-01","" {
            set rejected=0
            try { set ignored=tool.GetDailyPrices(word,bad) } catch error { set rejected=1 }
            if 'rejected { set failures=failures+1 write "FAIL invalid date: ",bad,! }
        }
        set rejected=0
        try { set ignored=tool.GetDailyPrices("   ",day) } catch error { set rejected=1 }
        if 'rejected { set failures=failures+1 write "FAIL empty name",! }
        set quote=##class(External.Demo.Price).%New(), quote.Name=word_" special", quote.Day=+$horolog, quote.Price=9.99
        set sc=quote.%Save()
        if '$SYSTEM.Status.IsOK(sc) { throw ##class(%Exception.StatusException).CreateFromStatus(sc) }
        set result=tool.GetDailyPrices(word,day)
        if result.count '= 3 { set failures=failures+1 write "FAIL additional matching product",! }
        set search=tool.SearchInventory(word)
        if '$isobject(search) { set failures=failures+1 write "FAIL product name search",! }
        set sc=##class(External.Demo.Bootstrap).Seed()
        if '$SYSTEM.Status.IsOK(sc) { throw ##class(%Exception.StatusException).CreateFromStatus(sc) }
        set after=tool.GetDailyPrices(word,day)
        if after.%ToJSON() '= result.%ToJSON() { set failures=failures+1 write "FAIL idempotent quotation seed",! }
    } catch error {
        set failures=failures+1
        write "FAIL exception: ",error.DisplayString(),!
    }
    trollback
    write "INVENTORY_FAILURES=",failures,!
    return failures
}
}

