Include %occStatus

/// Stateful chat facade over governed AI Hub agents.
Class App.AIHub.ChatService
{

ClassMethod Send(agentName As %String, message As %String,
    conversationId As %String = "", username As %String = "",
    Output result As %DynamicObject) As %Status
{
    if username = "" set username = $username
    set sc = ##class(App.AIHub.Policy.UserAccess).Check(username, agentName)
    if $$$ISERR(sc) quit sc
    if agentName = "" quit $$$ERROR($$$GeneralError, "agentName is required")
    if message = "" quit $$$ERROR($$$GeneralError, "message is required")

    set sc = ##class(App.AIHub.AgentFactory).Create(agentName, .agent)
    if $$$ISERR(sc) quit sc

    if conversationId = "" {
        set conversationId = $translate($SYSTEM.Util.CreateGUID(), "{}", "")
        set session = agent.CreateSession()
        set sc = session.%Save()
        if $$$ISERR(sc) quit sc
        set conversation = ##class(App.Governance.ChatConversation).%New()
        set conversation.ConversationId = conversationId
        set conversation.AgentName = agentName
        set conversation.Username = username
        set conversation.SessionId = session.%Id()
        set conversation.CreatedAt = $zdatetime($horolog, 3)
    } else {
        set rs = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT ID, AgentName, Username, SessionId FROM App_Governance.ChatConversation " _
            "WHERE ConversationId = ?", conversationId)
        if rs.%SQLCODE < 0 quit $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
        if 'rs.%Next() quit $$$ERROR($$$GeneralError, "Conversation does not exist")
        if rs.%Get("Username") '= username quit $$$ERROR($$$GeneralError, "Conversation belongs to another IRIS user")
        if rs.%Get("AgentName") '= agentName quit $$$ERROR($$$GeneralError, "Conversation belongs to another agent")
        set conversation = ##class(App.Governance.ChatConversation).%OpenId(rs.%Get("ID"))
        // AI Hub keeps a native runtime token in the session. Load() reopens
        // the persistent object and reconstitutes that token for this CSP job.
        set session = ##class(%AI.Agent.Session).Load(rs.%Get("SessionId"), agent.Provider)
        if '$isobject(session) quit $$$ERROR($$$GeneralError, "AI Hub session is no longer available")
    }

    try {
        set response = agent.Chat(session, message)
        set content = response.Content
        set sc = session.%Save()
    } catch exception {
        set sc = exception.AsStatus()
    }
    if $$$ISERR(sc) quit sc

    tstart
    set conversation.UpdatedAt = $zdatetime($horolog, 3)
    set sc = conversation.%Save()
    if $$$ISERR(sc) { trollback  quit sc }
    set requestId = ##class(App.AIHub.RuntimeContext).GetRequestId()
    set sc = ##class(App.Governance.ChatMessage).Add(
        conversationId, "user", message, requestId)
    if $$$ISERR(sc) { trollback  quit sc }
    set sc = ##class(App.Governance.ChatMessage).Add(
        conversationId, "assistant", content, requestId)
    if $$$ISERR(sc) { trollback  quit sc }
    tcommit

    set result = {
        "requestId":(requestId), "conversationId":(conversationId), "agentName":(agentName),
        "username":(username), "content":(content),
        "messages":(##class(App.Governance.ChatMessage).ListJSON(conversationId))
    }
    quit $$$OK
}

}
