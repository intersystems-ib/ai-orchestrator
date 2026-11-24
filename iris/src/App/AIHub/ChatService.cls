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
    if $$$ISERR(sc) return sc
    if agentName = "" return $$$ERROR($$$GeneralError, "agentName is required")
    if message = "" return $$$ERROR($$$GeneralError, "message is required")

    set sc = ##class(App.AIHub.AgentFactory).Create(agentName, .agent)
    if $$$ISERR(sc) return sc

    set sc = ##class(App.AIHub.ContextBudget).Configuration(agentName, .config, .limits)
    if $$$ISERR(sc) return sc

    if conversationId = "" {
        set conversationId = $translate($SYSTEM.Util.CreateGUID(), "{}", "")
        set session = agent.CreateSession(config)
        set sc = session.%Save()
        if $$$ISERR(sc) return sc
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
        if rs.%SQLCODE < 0 return $$$ERROR($$$SQLError, rs.%SQLCODE, rs.%Message)
        if 'rs.%Next() return $$$ERROR($$$GeneralError, "Conversation does not exist")
        if rs.%Get("Username") '= username return $$$ERROR($$$GeneralError, "Conversation belongs to another IRIS user")
        if rs.%Get("AgentName") '= agentName return $$$ERROR($$$GeneralError, "Conversation belongs to another agent")
        set conversation = ##class(App.Governance.ChatConversation).%OpenId(rs.%Get("ID"))
        // The agent reopens persisted state and initializes its native runtime
        // for this process using the preview SDK's session lifecycle API.
        set session = agent.OpenSession(rs.%Get("SessionId"), config)
        if '$isobject(session) return $$$ERROR($$$GeneralError, "AI Hub session is no longer available")
        set sc = session.Import(conversation.SessionState)
        if $$$ISERR(sc) return sc
    }

    try {
        set sc = ##class(App.AIHub.ContextBudget).Prepare(agent, session, message, limits, .compacted, .summaryMethod)
        if $$$ISERR(sc) return sc
        if compacted set summarizedAt = $zdatetime($horolog, 3)
        set response = agent.Chat(session, message)
        set content = response.Content
        set sc = session.%Save()
        // Keep the public SDK export alongside ownership and transcript for
        // explicit state restoration across application requests.
        set sessionState = session.Export()
    } catch exception {
        set sc = exception.AsStatus()
    }
    if $$$ISERR(sc) return sc

    tstart
    if compacted {
        set conversation.LastSummaryAt = summarizedAt
        set conversation.LastSummaryMethod = summaryMethod
        set conversation.SummaryCount = +conversation.SummaryCount + 1
    }
    set conversation.SessionState = sessionState
    set conversation.UpdatedAt = $zdatetime($horolog, 3)
    set sc = conversation.%Save()
    if $$$ISERR(sc) { trollback  return sc }
    set requestId = ##class(App.AIHub.RuntimeContext).GetRequestId()
    set sc = ##class(App.Governance.ChatMessage).Add(
        conversationId, "user", message, requestId)
    if $$$ISERR(sc) { trollback  return sc }
    set sc = ##class(App.Governance.ChatMessage).Add(
        conversationId, "assistant", content, requestId)
    if $$$ISERR(sc) { trollback  return sc }
    tcommit

    // Read the native runtime while this session is still loaded. Telemetry
    // must never turn a successfully saved answer into a failed chat request.
    set statistics = ""
    try {
        set statistics = session.GetStats()
    } catch statisticsException {
        set statistics = ""
    }

    set result = {
        "requestId":(requestId), "conversationId":(conversationId), "agentName":(agentName),
        "username":(username), "content":(content),
        "contextManagement":{ "inputBudget":(limits.inputBudget), "responseReserve":(limits.responseReserve),
            "modelCapacity":(limits.modelCapacity), "summarized":(compacted), "summaryMethod":(summaryMethod),
            "lastSummarizedAt":(conversation.LastSummaryAt), "lastSummaryMethod":(conversation.LastSummaryMethod),
            "summaryCount":(+conversation.SummaryCount) },
        "messages":(##class(App.Governance.ChatMessage).ListJSON(conversationId))
    }
    if $isobject(statistics) {
        do result.%Set("statistics", statistics)
    } else {
        do result.%Set("statistics", "", "null")
    }
    return $$$OK
}

}
