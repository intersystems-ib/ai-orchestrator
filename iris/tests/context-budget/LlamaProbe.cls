Include %occStatus

/// Optional integration probe: disposable IRIS on the local Compose network.
/// Uses the local Llama endpoint; never saves sessions or business records.
Class App.Test.ContextLlamaProbe Extends %RegisteredObject
{
ClassMethod Run(endpoint As %String = "http://llama:8000/v1",
    model As %String = "llama-3.1-8b-instruct") As %Integer
{
    set failures=0
    try {
        set provider=##class(%AI.Provider).Create("nim",{"api_key":"not-needed","base_url":(endpoint)})
        set agent=##class(%AI.Agent).%New(provider),agent.Model=model,agent.SystemPrompt="Assist with orders."
        set sc=agent.%Init()
        if $$$ISERR(sc) throw ##class(%Exception.StatusException).CreateFromStatus(sc)
        for count=1000,20000 {
            set session=agent.CreateSession({"max_tokens":256})
            set text=""
            for i=1:1:count {set text=text_" hello"}
            do session.InsertMessage(0,{"role":"user","content":(text_" ORDER-42 is pending.")})
            do session.InsertMessage(1,{"role":"assistant","content":"ORDER-42 pending."})
            set sc=session.Summarize(provider,model,1,"Summarize briefly, preserving ORDER-42 and its status. Return valid JSON.")
            write "NATIVE_REPETITIONS=",count," SUCCESS=",$SYSTEM.Status.IsOK(sc),!
            if count=1000, $$$ISERR(sc) {set failures=failures+1 do $SYSTEM.OBJ.DisplayError(sc)}
            if count=20000 {
                if $$$ISOK(sc) {set failures=failures+1 write "Expected native context overflow with a 16384-token endpoint",!}
                if $$$ISERR(sc) write "NATIVE_LARGE_ERROR=",$SYSTEM.Status.GetErrorText(sc),!
                set limits={"inputBudget":15360,"responseReserve":1024,"modelCapacity":16384}
                set sc=##class(App.AIHub.ContextBudget).Prepare(agent,session,"What is pending?",limits,.compacted,.mechanism)
                if $$$ISERR(sc) {set failures=failures+1 do $SYSTEM.OBJ.DisplayError(sc)}
                if $$$ISOK(sc) {
                    write "LARGE_HISTORY_RECOVERY=",mechanism," MESSAGES=",session.MessageCount(),!
                    if (mechanism'="blocks") || 'compacted set failures=failures+1
                    if '$find($zconvert(session.Export(),"U"),"ORDER-42") {set failures=failures+1 write "Order identifier missing from recovered memory",!}
                }
            }
        }
    } catch exception {
        set failures=failures+1
        write "EXCEPTION ",$SYSTEM.Status.GetErrorText(exception.AsStatus()),!
    }
    write "LLAMA_CONTEXT_PROBE_FAILURES=",failures,!
    return failures
}
}
