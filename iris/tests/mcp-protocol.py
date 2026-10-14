"""Exercise the native IRIS MCP connection against a deterministic HTTP fixture.

Run inside the application container after loading App.AIHub.MCP.Connection.
Uses only Python's standard library; no LLM requests or database writes.
"""
import http.server
import json
import subprocess
import threading
import unittest


class Fixture(http.server.BaseHTTPRequestHandler):
    sessions = set()
    failures = []

    def send(self, status, body=None, session=None, sse=False, location=None, bare=False):
        raw = b''
        if body is not None:
            text = json.dumps(body, ensure_ascii=False, indent=2)
            if sse:
                notice = json.dumps({'jsonrpc': '2.0', 'method': 'notifications/tools/list_changed'})
                text = ': keepalive\n\ndata: \n\ndata: ' + notice + '\n\n' + ''.join('data: ' + line + '\n' for line in text.splitlines()) + '\n'
            raw = text.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'text/event-stream' if sse else 'application/json' if bare else 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(raw)))
        if session:
            self.send_header('Mcp-Session-Id', session)
        if location:
            self.send_header('Location', location)
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self):
        mode = self.path.strip('/')
        message = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        if self.headers.get('Authorization') != 'Bearer test-token':
            self.failures.append('Authorization missing')
            self.send(401)
            return
        if mode == 'redirect':
            self.send(307, location='/unexpected-redirect')
            return
        if mode == 'unexpected-redirect':
            self.failures.append('Redirect was followed')
            self.send(400)
            return
        if mode == 'http401':
            self.send(401)
            return
        rpc = message['method']
        request_id = message.get('id')
        if rpc == 'initialize':
            session = mode + '-session'
            self.sessions.add(session)
            result = {'protocolVersion': '2025-03-26', 'capabilities': {'tools': {}}, 'serverInfo': {'name': 'fixture', 'version': '1'}}
            self.send(200, {'jsonrpc': '2.0', 'id': request_id, 'result': result}, session, mode == 'sse')
            return
        if self.headers.get('Mcp-Session-Id') != mode + '-session':
            self.failures.append('Session header missing')
            self.send(400)
            return
        if rpc == 'notifications/initialized':
            self.send(202)
            return
        if rpc == 'tools/list':
            page = message['params'].get('cursor', '')
            name = 'Echo' if not page or mode == 'duplicate' else 'Other'
            tool = {'name': name, 'description': 'Información café 漢字', 'inputSchema': {'type': 'object', 'properties': {}}}
            if mode == 'badSchema':
                tool['inputSchema'] = {'type': 'string'}
            result = {'tools': [tool]}
            if not page or mode == 'cursorLoop':
                result['nextCursor'] = 'page-2'
            response = {'jsonrpc': '2.0', 'id': request_id + (1 if mode == 'wrongId' else 0), 'result': result}
            if mode == 'rpcError':
                response = {'jsonrpc': '2.0', 'id': request_id, 'error': {'code': -32603, 'message': 'catalog unavailable'}}
            self.send(200, response, sse=mode == 'sse', bare=mode == 'jsonBare')
            return
        if rpc == 'tools/call':
            result = {'content': [{'type': 'text', 'text': 'remote failure'}], 'isError': True}
            self.send(200, {'jsonrpc': '2.0', 'id': request_id, 'result': result})
            return
        self.send(400)

    def do_DELETE(self):
        self.sessions.discard(self.headers.get('Mcp-Session-Id'))
        self.send(204)

    def log_message(self, *args):
        pass


class ProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Fixture)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def run_case(self, mode, expected, message='', call=False):
        url = f'http://127.0.0.1:{self.server.server_port}/{mode}'
        operation = 'set sc=connection.Call("tools/call",{"name":"Echo","arguments":{}},.result)' if call else 'set sc=connection.ListTools(.result)'
        script = f'''zn "APP"
set connection=##class(App.AIHub.MCP.Connection).%New()
set sc=connection.Open("{url}","test-token")
if $SYSTEM.Status.IsOK(sc) {{ {operation} }}
write "PROTOCOL_OK=",$SYSTEM.Status.IsOK(sc),!
if $SYSTEM.Status.IsOK(sc) write $zconvert(result.%ToJSON(),"O","UTF8"),!
if '$SYSTEM.Status.IsOK(sc) write $SYSTEM.Status.GetErrorText(sc),!
do connection.Close()
halt
'''
        run = subprocess.run(['iris', 'session', 'IRIS'], input=script, text=True, capture_output=True, timeout=45)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertIn('PROTOCOL_OK=' + str(int(expected)), run.stdout, run.stdout + run.stderr)
        self.assertNotIn('test-token', run.stdout)
        if message:
            self.assertIn(message, run.stdout)
        self.assertFalse(Fixture.sessions, Fixture.sessions)
        self.assertFalse(Fixture.failures, Fixture.failures)

    def test_json_pagination_unicode_auth_session(self):
        self.run_case('json', True, 'Información café 漢字')

    def test_sse_multiline_notifications(self):
        self.run_case('sse', True, 'Información café 漢字')

    def test_json_without_charset(self):
        self.run_case('jsonBare', True, 'Información café 漢字')

    def test_invalid_schema(self):
        self.run_case('badSchema', False, 'input schema')

    def test_duplicate_tools(self):
        self.run_case('duplicate', False, 'Duplicate MCP tool')

    def test_repeated_cursor(self):
        self.run_case('cursorLoop', False, 'pagination cursor')

    def test_wrong_response_id(self):
        self.run_case('wrongId', False, 'no matching response')

    def test_rpc_error(self):
        self.run_case('rpcError', False, 'catalog unavailable')

    def test_http_error(self):
        self.run_case('http401', False, 'MCP HTTP 401')

    def test_no_credential_redirect(self):
        self.run_case('redirect', False, 'MCP HTTP 307')

    def test_tool_error_preserved(self):
        self.run_case('callError', True, 'remote failure', call=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
