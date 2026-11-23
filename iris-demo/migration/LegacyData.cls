Include %occStatus

/// Offline migration helper. Not included in either application image or MCP catalog.
Class Demo.Migration.LegacyData
{
ClassMethod Export(path As %String) As %Status
{
    set file=##class(%Stream.FileCharacter).%New()
    set file.Filename=path, file.TranslateTable="UTF8"
    set header={"format":"ai-orchestrator-demo-data-v1"}
    do file.WriteLine(header.%ToJSON())
    for table="Inventory","Shipment","ShipmentProduct" {
        set base="^App.Demo."_table_"D", ref=base
        if $data(@ref)#2 do ..WriteNode(file, ref)
        for {
            set ref=$query(@ref)
            if ref="" quit
            if $qsubscript(ref,0)'=base quit
            do ..WriteNode(file, ref)
        }
    }
    return file.%Save()
}

ClassMethod WriteNode(file As %Stream.FileCharacter, ref As %String) [ Private ]
{
    set row={"ref":(ref)}
    do row.%Set("value",$get(@ref),"string")
    do file.WriteLine(row.%ToJSON())
}

/// Only use on a newly created, offline destination. Replaces its sample extents.
ClassMethod Import(path As %String) As %Status
{
    if $namespace'="DEMO" return $$$ERROR($$$GeneralError,"Import requires namespace DEMO")
    if $data(^DemoDataImported) return $$$ERROR($$$GeneralError,"Data was already migrated; refusing to overwrite")
    set file=##class(%Stream.FileCharacter).%New()
    set file.Filename=path, file.TranslateTable="UTF8"
    set header={}.%FromJSON(file.ReadLine())
    if header.%Get("format")'="ai-orchestrator-demo-data-v1" return $$$ERROR($$$GeneralError,"Invalid migration file")
    tstart
    try {
        for table="Inventory","Shipment","ShipmentProduct" {
            set base="^App.Demo."_table_"D"
            kill @base
        }
        while 'file.AtEnd {
            set line=file.ReadLine()
            if line="" continue
            set row={}.%FromJSON(line), ref=row.%Get("ref"), base=$qsubscript(ref,0)
            if (base'="^App.Demo.InventoryD")&&(base'="^App.Demo.ShipmentD")&&(base'="^App.Demo.ShipmentProductD") {
                throw ##class(%Exception.General).%New("Migration contains an unexpected global")
            }
            set @ref=row.%Get("value")
        }
        set ^DemoDataImported=$zdatetime($horolog,3)
        tcommit
    } catch ex {
        trollback
        return ex.AsStatus()
    }
    for class="App.Demo.Inventory","App.Demo.Shipment","App.Demo.ShipmentProduct" {
        set sc=$classmethod(class,"%BuildIndices")
        if $$$ISERR(sc) return sc
    }
    return $$$OK
}

/// Rename only known sample values; preserve custom product names and stock.
ClassMethod Translate(path As %String, prices As %Boolean=0) As %Status
{
    set file=##class(%Stream.FileCharacter).%New()
    set file.Filename=path, file.TranslateTable="UTF8"
    set map={}.%FromJSON(file)
    tstart
    try {
        for i=0:1:(map.products.%Size()-1) {
            set item=map.products.%Get(i)
            if prices {
                set rs=##class(%SQL.Statement).%ExecDirect(,"UPDATE External_Demo.Price SET Name=? WHERE Name=?",item.to,item.from)
            } else {
                set rs=##class(%SQL.Statement).%ExecDirect(,"UPDATE App_Demo.Inventory SET Name=? WHERE Sku=? AND Name=?",item.to,item.sku,item.from)
            }
            if rs.%SQLCODE<0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message))
        }
        if 'prices {
            for i=0:1:(map.customers.%Size()-1) {
                set item=map.customers.%Get(i)
                set rs=##class(%SQL.Statement).%ExecDirect(,"UPDATE App_Demo.Shipment SET Customer=? WHERE Customer=?",item.to,item.from)
                if rs.%SQLCODE<0 throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLError,rs.%SQLCODE,rs.%Message))
            }
        }
        tcommit
    } catch ex {
        trollback
        return ex.AsStatus()
    }
    return $$$OK
}
}
