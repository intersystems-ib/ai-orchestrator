/// Example to import manually in APP. Does not configure or start a production.
Class App.Demo.AgentProcess Extends Ens.BusinessProcessBPL
{
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language="objectscript" request="Ens.StringRequest" response="Ens.StringResponse">
  <sequence>
    <call name="Consultar agente" target="Demo Agent Operation" async="0" timeout="300">
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
