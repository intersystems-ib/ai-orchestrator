"""Deterministic local LLM fixture. Never connects to an external provider."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        messages = payload.get('messages', [])
        prompt = next((m['content'] for m in reversed(messages) if m['role'] == 'user'), '')
        tools = payload.get('tools', [])
        if tools and not any(m['role'] == 'tool' for m in messages):
            message = {'role': 'assistant', 'content': None, 'tool_calls': [{
                'id': 'bpl-tool-1', 'type': 'function',
                'function': {'name': tools[0]['function']['name'], 'arguments': '{"name":"arroz"}'},
            }]}
            finish = 'tool_calls'
        else:
            message = {'role': 'assistant', 'content': 'BPL_OK:' + prompt}
            finish = 'stop'
        result = {'id': 'chatcmpl-bpl-test', 'object': 'chat.completion', 'created': 1,
                  'model': 'bpl-fixture', 'choices': [{'index': 0, 'message': message, 'finish_reason': finish}],
                  'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2}}
        body = json.dumps(result, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


ThreadingHTTPServer(('127.0.0.1', 18089), Handler).serve_forever()
