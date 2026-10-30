/// Compile only for the isolated BPL integration test.
Class App.Test.BPLProcess Extends Ens.BusinessProcessBPL
{

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language="objectscript" request="Ens.StringRequest" response="Ens.StringResponse">
  <sequence>
    <call name="Ask agent" target="BPL Agent" async="0" timeout="30">
      <request type="Ens.StringRequest">
        <assign property="callrequest.StringValue" value="request.StringValue" action="set" />
      </request>
      <response type="Ens.StringResponse">
        <assign property="response.StringValue" value="callresponse.StringValue" action="set" />
      </response>
    </call>
    <reply />
  </sequence>
</process>
}

}
