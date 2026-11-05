"""Local deterministic provider for the real nested AI Hub tool-call loop."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        with open('/tmp/delegation-requests.jsonl', 'a', encoding='utf-8') as log:
            log.write(json.dumps(payload, ensure_ascii=False) + '\n')
        model = payload.get('model')
        messages = payload.get('messages', [])
        tools = [t['function']['name'] for t in payload.get('tools', [])]
        results = [m for m in messages if m['role'] == 'tool']
        system = ' '.join(str(m.get('content', '')) for m in messages if m['role'] == 'system')
        parent = model == 'delegation-parent'
        expected = 'PARENT_ONLY' if parent else 'SPECIALIST_ONLY'
        if expected not in system or ('SPECIALIST_ONLY' if parent else 'PARENT_ONLY') in system:
            self.send_error(400, 'Fixture detected wrong model or leaked instructions')
            return
        selected = None
        if parent and not results:
            selected = next(t for t in tools if t.startswith('delegate_agent_'))
            arguments = {'prompt': 'Consulta café y existencias'}
        elif len(results) < (2 if parent else 1):
            selected = next(t for t in tools if t == 'SearchInventory')
            arguments = {'name': 'Café'}
        if selected:
            message = {'role': 'assistant', 'content': None, 'tool_calls': [{
                'id': 'call-' + str(len(results)), 'type': 'function',
                'function': {'name': selected, 'arguments': json.dumps(arguments)},
            }]}
            finish = 'tool_calls'
        else:
            text = 'SPECIALIST:inventario consultado'
            if parent:
                text = 'DELEGATION_OK' if 'SPECIALIST:' in json.dumps(results) else 'MISSING_SPECIALIST'
            message = {'role': 'assistant', 'content': text}
            finish = 'stop'
        result = {'id': 'chatcmpl-delegation-test', 'object': 'chat.completion', 'created': 1,
                  'model': model, 'choices': [{'index': 0, 'message': message, 'finish_reason': finish}],
                  'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2}}
        body = json.dumps(result, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


ThreadingHTTPServer(('127.0.0.1', 18090), Handler).serve_forever()
