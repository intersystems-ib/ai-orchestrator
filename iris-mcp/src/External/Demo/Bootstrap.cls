Include %occStatus

Class External.Demo.Bootstrap
{

ClassMethod Seed() As %Status
{
    tstart
    set sc = ##class(External.Demo.Price).SeedDemo()
    if $$$ISERR(sc) {
        trollback
        return sc
    }
    tcommit
    return ##class(External.Demo.Price).%BuildIndices($listbuild("NameSearchIndex"))
}

}
