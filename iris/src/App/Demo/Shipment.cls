Include %occStatus

/// Shipment header for the demo inventory domain.
Class App.Demo.Shipment Extends %Persistent
{

Property ShipmentReference As %String(MAXLEN = 80) [ Required ];
Property ShipmentDate As %Date [ Required ];
Property ReceptionDate As %Date;
Property TotalAmount As %Numeric(SCALE = 2) [ InitialExpression = 0 ];
Property Customer As %String(MAXLEN = 200) [ Required ];

Index ReferenceIndex On ShipmentReference [ Unique ];
Index ShipmentDateIndex On ShipmentDate;

/// Creates reproducible shipments and their product lines without overwriting data.
ClassMethod SeedDemo(Output created As %Integer) As %Status
{
    set created = 0
    set shipments = [
        {"reference":"SHP-2026-001","shipmentDate":"2026-09-03","receptionDate":"2026-09-05","customer":"Mercado Central Madrid","lines":[{"sku":"INV-001","quantity":8,"totalCost":71.60},{"sku":"INV-004","quantity":12,"totalCost":38.40},{"sku":"INV-009","quantity":5,"totalCost":34.75}]},
        {"reference":"SHP-2026-002","shipmentDate":"2026-09-08","receptionDate":"2026-09-10","customer":"Distribuciones Levante","lines":[{"sku":"INV-002","quantity":10,"totalCost":49.50},{"sku":"INV-006","quantity":20,"totalCost":43.80},{"sku":"INV-014","quantity":15,"totalCost":33.75}]},
        {"reference":"SHP-2026-003","shipmentDate":"2026-09-14","receptionDate":"2026-09-17","customer":"Alimentos del Norte","lines":[{"sku":"INV-003","quantity":14,"totalCost":62.30},{"sku":"INV-015","quantity":18,"totalCost":57.60}]},
        {"reference":"SHP-2026-004","shipmentDate":"2026-09-21","receptionDate":"2026-09-23","customer":"Comercial Mediterráneo","lines":[{"sku":"INV-005","quantity":9,"totalCost":78.75},{"sku":"INV-007","quantity":16,"totalCost":45.60},{"sku":"INV-008","quantity":12,"totalCost":35.40}]},
        {"reference":"SHP-2026-005","shipmentDate":"2026-09-28","receptionDate":"2026-10-01","customer":"Supermercados Sierra","lines":[{"sku":"INV-001","quantity":10,"totalCost":89.50},{"sku":"INV-010","quantity":8,"totalCost":31.20},{"sku":"INV-016","quantity":6,"totalCost":28.50}]},
        {"reference":"SHP-2026-006","shipmentDate":"2026-10-02","receptionDate":"2026-10-04","customer":"Hostelería Costa Sur","lines":[{"sku":"INV-011","quantity":18,"totalCost":46.80},{"sku":"INV-012","quantity":14,"totalCost":41.30},{"sku":"INV-019","quantity":20,"totalCost":52.00}]},
        {"reference":"SHP-2026-007","shipmentDate":"2026-10-09","receptionDate":"2026-10-12","customer":"Tiendas Gourmet Ibéricas","lines":[{"sku":"INV-003","quantity":10,"totalCost":44.50},{"sku":"INV-009","quantity":7,"totalCost":48.65},{"sku":"INV-017","quantity":9,"totalCost":53.10}]},
        {"reference":"SHP-2026-008","shipmentDate":"2026-10-16","receptionDate":"","customer":"Plataforma Logística Centro","lines":[{"sku":"INV-013","quantity":22,"totalCost":39.60},{"sku":"INV-018","quantity":30,"totalCost":27.00},{"sku":"INV-020","quantity":8,"totalCost":76.00}]}
    ]

    for index = 0:1:(shipments.%Size() - 1) {
        set source = shipments.%Get(index)
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID FROM App_Demo.Shipment WHERE ShipmentReference = ?", source.reference)
        if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
        if rs.%Next() continue

        tstart
        set shipment = ..%New()
        set shipment.ShipmentReference = source.reference
        set shipment.ShipmentDate = $zdateh(source.shipmentDate, 3)
        if source.receptionDate '= "" {
            set shipment.ReceptionDate = $zdateh(source.receptionDate, 3)
        }
        set shipment.Customer = source.customer
        set shipment.TotalAmount = 0
        set sc = shipment.%Save()
        if $$$ISERR(sc) { trollback  return sc }

        set total = 0
        set lines = source.lines
        for lineIndex = 0:1:(lines.%Size() - 1) {
            set sourceLine = lines.%Get(lineIndex)
            set productResult = ##class(%SQL.Statement).%ExecDirect(,
                "SELECT ID FROM App_Demo.Inventory WHERE Sku = ?", sourceLine.sku)
            if productResult.%SQLCODE < 0 {
                trollback
                return $$$ERROR($$$SQLError, productResult.%SQLCODE, productResult.%Message)
            }
            if 'productResult.%Next() {
                trollback
                return $$$ERROR($$$GeneralError, "Inventory product does not exist: " _ sourceLine.sku)
            }
            set product = ##class(App.Demo.Inventory).%OpenId(productResult.%Get("ID"))
            set shipmentProduct = ##class(App.Demo.ShipmentProduct).%New()
            set shipmentProduct.Shipment = shipment
            set shipmentProduct.Product = product
            set shipmentProduct.Quantity = sourceLine.quantity
            set shipmentProduct.TotalCost = sourceLine.totalCost
            set sc = shipmentProduct.%Save()
            if $$$ISERR(sc) { trollback  return sc }
            set total = total + sourceLine.totalCost
        }
        set shipment.TotalAmount = total
        set sc = shipment.%Save()
        if $$$ISERR(sc) { trollback  return sc }
        tcommit
        set created = created + 1
    }
    return $$$OK
}

}
