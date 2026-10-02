/// Persisted transcript entry belonging to a governed chat.
Class App.Governance.ChatMessage Extends %Persistent
{

Property ConversationId As %String(MAXLEN = 64) [ Required ];
Property Role As %String(VALUELIST = ",user,assistant") [ Required ];
Property Content As %String(MAXLEN = "");
Property RequestId As %String(MAXLEN = 64);
Property CreatedAt As %TimeStamp;

Index ConversationIndex On ConversationId;

ClassMethod Add(conversationId As %String, role As %String, content As %String,
    requestId As %String = "") As %Status
{
    set item = ..%New()
    set item.ConversationId = conversationId
    set item.Role = role
    set item.Content = content
    set item.RequestId = requestId
    set item.CreatedAt = $zdatetime($horolog, 3)
    quit item.%Save()
}

ClassMethod ListJSON(conversationId As %String) As %DynamicArray
{
    set output = []
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT ID, ""Role"" AS MessageRole, Content, RequestId, CreatedAt FROM App_Governance.ChatMessage " _
        "WHERE ConversationId = ? ORDER BY ID", conversationId)
    if rs.%SQLCODE < 0 quit output
    while rs.%Next() {
        do output.%Push({
            "id":(rs.%Get("ID")), "role":(rs.%Get("MessageRole")),
            "content":(rs.%Get("Content")), "requestId":(rs.%Get("RequestId")),
            "createdAt":(rs.%Get("CreatedAt"))
        })
    }
    quit output
}

}
