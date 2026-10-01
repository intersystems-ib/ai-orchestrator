Class App.Governance.ClassUtil
{

/// Returns true when className is baseClass or inherits from it.
/// This uses the compiled dictionary, so only deployable classes can be registered.
ClassMethod IsSubclass(className As %String, baseClass As %String) As %Boolean
{
    if className = baseClass quit 1
    if (className = "") || (baseClass = "") quit 0
    kill visited
    quit ..WalkSuperclasses(className, baseClass, .visited)
}

ClassMethod WalkSuperclasses(className As %String, baseClass As %String, ByRef visited) As %Boolean [ Internal, Private ]
{
    if $data(visited(className)) quit 0
    set visited(className) = 1

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Super FROM %Dictionary.CompiledClass WHERE Name = ?", className)
    if 'rs.%Next() quit 0

    set superclasses = rs.%Get("Super")
    set found = 0
    for index = 1:1:$length(superclasses, ",") {
        set superclass = $zstrip($piece(superclasses, ",", index), "<W")
        if superclass = "" continue
        if superclass = baseClass {
            set found = 1
            quit
        }
        if ..WalkSuperclasses(superclass, baseClass, .visited) {
            set found = 1
            quit
        }
    }
    quit found
}

ClassMethod ValidName(name As %String) As %Boolean
{
    quit (name '= "") && (name '[ ",")
}

ClassMethod ArrayToCSV(values As %DynamicArray) As %String
{
    set csv = ""
    if '$isobject(values) quit csv
    for index = 0:1:(values.%Size() - 1) {
        set value = values.%Get(index)
        if value = "" continue
        set csv = csv _ $select(csv="":"", 1:",") _ value
    }
    quit csv
}

ClassMethod CSVToArray(csv As %String) As %DynamicArray
{
    set values = []
    for index = 1:1:$length(csv, ",") {
        set value = $piece(csv, ",", index)
        if value '= "" do values.%Push(value)
    }
    quit values
}

}
