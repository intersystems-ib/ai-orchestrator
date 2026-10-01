Include %occStatus

/// IRIS users authorized to invoke governed AI agents.
Class App.Governance.AIUser Extends (%Persistent, %JSON.Adaptor)
{

Property Username As %String(MAXLEN = 128) [ Required ];
Property Enabled As %Boolean [ InitialExpression = 1 ];
Property CreatedAt As %TimeStamp;
Property CreatedBy As %String(MAXLEN = 128);

Index UsernameIndex On Username [ Unique ];

ClassMethod Set(payload As %DynamicObject, Output result As %DynamicObject) As %Status
{
    set username = payload.%Get("username", "")
    if username = "" quit $$$ERROR($$$GeneralError, "username is required")
    if '..IRISUserExists(username) quit $$$ERROR($$$GeneralError, "IRIS user does not exist: " _ username)

    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.AIUser WHERE Username = ?", username)
    if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
    if rs.%Next() {
        set item = ..%OpenId(rs.%Get("ID"))
    } else {
        set item = ..%New()
        set item.Username = username
        set item.CreatedAt = $zdatetime($horolog, 3)
        set item.CreatedBy = $username
    }
    set item.Enabled = payload.%Get("enabled", 1)
    set sc = item.%Save()
    if $$$ISERR(sc) quit sc
    set result = ..OneJSON(item)
    quit $$$OK
}

ClassMethod IsAuthorized(username As %String = "") As %Boolean
{
    if username = "" set username = $username
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID FROM App_Governance.AIUser WHERE Username = ? AND Enabled = 1", username)
    quit rs.%Next()
}

ClassMethod ListJSON() As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, Username, Enabled, CreatedAt, CreatedBy " _
        "FROM App_Governance.AIUser ORDER BY Username")
    while rs.%Next() {
        do output.%Push({
            "id":(rs.%Get("ID")), "username":(rs.%Get("Username")),
            "enabled":(rs.%Get("Enabled")), "createdAt":(rs.%Get("CreatedAt")),
            "createdBy":(rs.%Get("CreatedBy")),
            "agents":(##class(App.Governance.AgentUser).ListForUser(rs.%Get("Username")))
        })
    }
    quit output
}

ClassMethod IRISUserExists(username As %String) As %Boolean [ Internal, Private ]
{
    set originalNamespace = $namespace
    set exists = 0
    try {
        zn "%SYS"
        set exists = $classmethod("Security.Users", "Exists", username)
    } catch exception {
        set exists = 0
    }
    zn originalNamespace
    quit exists
}

ClassMethod OneJSON(item As App.Governance.AIUser) As %DynamicObject [ Internal, Private ]
{
    quit {
        "id":(item.%Id()), "username":(item.Username), "enabled":(item.Enabled),
        "createdAt":(item.CreatedAt), "createdBy":(item.CreatedBy),
        "agents":(##class(App.Governance.AgentUser).ListForUser(item.Username))
    }
}

}
