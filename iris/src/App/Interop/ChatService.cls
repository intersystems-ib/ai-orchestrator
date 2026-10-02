Include %occStatus

/// Synchronous entry point used by the REST API to enter the production.
Class App.Interop.ChatService Extends Ens.BusinessService
{

Parameter ADAPTER = "";

Method OnProcessInput(pInput As App.Interop.Message.ChatRequest,
    Output pOutput As App.Interop.Message.ChatResponse,
    ByRef pHint As %String) As %Status
{
    quit ..SendRequestSync("AI Hub LLM Operation", pInput, .pOutput, 300,
        "Governed AI Hub request " _ pInput.RequestId)
}

}
