Include %occStatus

/// Run only in a disposable IRIS instance.
Class App.Test.ContextBudget Extends %RegisteredObject
{
Property Failures As %Integer [ InitialExpression = 0 ];

Method Check(condition As %Boolean, label As %String)
{
    if 'condition { set ..Failures = ..Failures + 1 write "FAIL ",label,! }
}

Method Require(sc As %Status)
{
    if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
}

Method Counters() As %DynamicObject
{
    set request=##class(%Net.HttpRequest).%New(),request.Server="127.0.0.1",request.Port=18091
    do ..Require(request.Get("/stats"))
    return {}.%FromJSON(request.HttpResponse.Data.Read())
}

Method Run() As %Integer
{
    try {
        do ..Require(##class(App.Governance.Model).Create({"name":"context-test", "provider":"nim",
            "modelId":"context-test", "baseUrl":"http://127.0.0.1:18091/v1", "apiKey":"not-needed",
            "maxContextTokens":4096, "status":"approved"}, .model))
        do ..Check(model.maxContextTokens=4096, "model capacity round trip")
        do ..Require(##class(App.Governance.Model).Update("context-test", {"maxContextTokens":5000}, .model))
        do ..Check(model.baseUrl="http://127.0.0.1:18091/v1", "capacity-only update preserves connection details")
        do ..Require(##class(App.Governance.Model).Update("context-test", {"maxContextTokens":4096}, .model))
        do ..Check($$$ISERR(##class(App.Governance.Model).Update("context-test", {"maxContextTokens":0}, .ignored)), "invalid model capacity")
        do ..Require(##class(App.Governance.Agent).Create({"name":"context-test", "modelName":"context-test",
            "contextBudget":1800, "responseReserve":256, "systemPrompt":"Assist with orders.", "status":"approved"}, .item))
        do ..Require(##class(App.Governance.Agent).Update("context-test", {"displayName":"Context test"}, .item))
        do ..Check((item.contextBudget=1800)&&(item.responseReserve=256), "partial update preserves budgets")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("context-test", {"contextBudget":4000}, .ignored)), "reject budget beyond model capacity")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("context-test", {"responseReserve":-1}, .ignored)), "reject negative reserve")
        do ..Check($$$ISERR(##class(App.Governance.Agent).Update("context-test", {"responseReserve":1.5}, .ignored)), "reject fractional reserve")
        do ..Check($$$ISERR(##class(App.Governance.Model).Update("context-test", {"maxContextTokens":1024}, .ignored)), "reject model capacity conflicting with agents")
        do ..Require(##class(App.Governance.AIUser).Set({"username":($username),"enabled":true}, .ignored))
        do ..Require(##class(App.Governance.AgentUser).SetForUser($username, ["context-test"]))
        do ..Require(##class(App.AIHub.ChatService).Send("context-test", "Track ORDER-42", "", $username, .first))
        do ..Check('first.contextManagement.summarized, "short first request does not summarize")
        set conversation = first.conversationId
        set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM App_Governance.ChatConversation WHERE ConversationId=?",conversation)
        do rs.%Next()
        set record=##class(App.Governance.ChatConversation).%OpenId(rs.%Get("ID"))
        set state={}.%FromJSON(record.SessionState)
        // Exceeds the agent budget but fits in the provider's serving window.
        for i=1:1:8 { do state.messages.%Push({"role":"user","content":($justify("ORDER-42 historical fact",600))}) }
        set record.SessionState=state.%ToJSON()
        do ..Require(record.%Save())
        do ..Require(##class(App.AIHub.ChatService).Send("context-test", "What is pending?", conversation, $username, .second))
        do ..Check(second.contextManagement.summaryMethod="sdk", "SDK is the primary summarization path")
        do ..Check(second.contextManagement.lastSummaryMethod="sdk", "SDK summary method persisted")
        do ..Check(second.contextManagement.lastSummarizedAt'="", "summary timestamp returned")
        do ..Check(second.contextManagement.summaryCount=1, "summary count starts at one")
        do ..Check(..Counters().blocks=0, "no block calls after successful native compaction")
        do ..Check(second.messages.%Size()=4, "full application transcript remains intact")
        do ..Check(second.statistics."total_interactions">first.statistics."total_interactions", "native statistics remain cumulative")
        set record=##class(App.Governance.ChatConversation).%OpenId(record.%Id())
        set state={}.%FromJSON(record.SessionState)
        for i=1:1:8 { do state.messages.%Push({"role":"user","content":($justify("ORDER-42 historical fact",2400))}) }
        do state.messages.%Push({"role":"assistant","content":"RECENT_ORDER-42_LITERAL"})
        set record.SessionState=state.%ToJSON()
        do ..Require(record.%Save())
        do ..Require(##class(App.AIHub.ChatService).Send("context-test", "Recover large history", conversation, $username, .third))
        do ..Check(third.contextManagement.summaryMethod="blocks", "blocks recover an explicit native context overflow")
        do ..Check(..Counters()."native_overflow">0, "provider actually rejected the native summary request")
        do ..Check(third.messages.%Size()=6, "fallback preserves full transcript")
        set record=##class(App.Governance.ChatConversation).%OpenId(record.%Id())
        do ..Check($find(record.SessionState,"RECENT_ORDER-42_LITERAL")>0, "fallback preserves recent assistant answer verbatim")
        // A very large retained message can survive a successful SDK summary.
        set record=##class(App.Governance.ChatConversation).%OpenId(record.%Id())
        set state={}.%FromJSON(record.SessionState)
        do state.messages.%Push({"role":"user","content":($justify("ORDER-42 latest fact",6000))})
        set record.SessionState=state.%ToJSON()
        do ..Require(record.%Save())
        set counters=..Counters()
        do ..Require(##class(App.AIHub.ChatService).Send("context-test", "Continue", conversation, $username, .third))
        do ..Check(third.contextManagement.summaryMethod="blocks", "fallback when successful SDK summary still exceeds agent budget")
        do ..Check(..Counters()."native_overflow"=counters."native_overflow", "retained-message fallback did not require provider overflow")
        do ..Require(##class(App.AIHub.ChatService).Send("context-test", "Continue", conversation, $username, .third))
        do ..Check(third.conversationId=conversation, "same conversation survives reload")
        do ..Check(third.contextManagement.lastSummaryMethod="blocks", "last summary method survives a later turn")
        do ..Check(third.contextManagement.summaryCount=3, "summary count survives reload without extra summaries")
        set before=third.messages.%Size()
        set sc=##class(App.AIHub.ChatService).Send("context-test", $justify("too long",7500), conversation, $username, .ignored)
        do ..Check($$$ISERR(sc), "oversized fixed input rejected without truncation")
        do ..Check(##class(App.Governance.ChatMessage).ListJSON(conversation).%Size()=before, "rejected input is not persisted")
        // A summary failure must not replace any persisted conversation state.
        set record=##class(App.Governance.ChatConversation).%OpenId(record.%Id())
        set state={}.%FromJSON(record.SessionState)
        do state.messages.%Push({"role":"user","content":("FAIL_SUMMARY"_$justify("",7500))})
        do state.messages.%Push({"role":"assistant","content":"Most recent answer"})
        set snapshot=state.%ToJSON(), record.SessionState=snapshot
        do ..Require(record.%Save())
        set counters=..Counters()
        set sc=##class(App.AIHub.ChatService).Send("context-test", "Continue", conversation, $username, .ignored)
        do ..Check($$$ISERR(sc), "summary provider failure propagated")
        do ..Check(..Counters().blocks=counters.blocks, "generic provider failure does not invoke block fallback")
        set record=##class(App.Governance.ChatConversation).%OpenId(record.%Id())
        do ..Check(record.SessionState=snapshot, "failed summary preserves persisted state")
        do ..Require(##class(App.Governance.Agent).Update("context-test", {"contextBudget":0}, .ignored))
        do ..Require(##class(App.AIHub.ContextBudget).Configuration("context-test", .config, .limits))
        do ..Check(limits.inputBudget=3840, "zero budget inherits capacity minus reserve")
    } catch exception {
        set ..Failures=..Failures+1
        write "EXCEPTION ",$SYSTEM.Status.GetErrorText(exception.AsStatus()),!
    }
    write "CONTEXT_BUDGET_FAILURES=",..Failures,!
    return ..Failures
}
}
