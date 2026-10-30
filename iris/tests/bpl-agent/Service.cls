Class App.Test.BPLService Extends Ens.BusinessService
{
Parameter ADAPTER = "";

Method OnProcessInput(pInput As Ens.StringRequest, Output pOutput As Ens.StringResponse,
    ByRef pHint As %String) As %Status
{
    quit ..SendRequestSync("BPL Process", pInput, .pOutput, 40)
}
}
