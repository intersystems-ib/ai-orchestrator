"""Deterministic context compaction fixture; no external model is called."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    counts = dict(native=0, blocks=0, chat=0, native_overflow=0, summary_failure=0)

    def send_json(self, value, status=200):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.send_json(self.counts)

    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        messages = payload.get('messages', [])
        schema = payload.get('response_format', {}).get('json_schema', {})
        native = schema.get('name') == 'conversation_summary'
        blocks = not native and any(str(m.get('content', '')).startswith('Summarize conversation history') for m in messages)
        summary = native or blocks
        kind = 'native' if native else 'blocks' if blocks else 'chat'
        self.counts[kind] += 1
        with open('/tmp/context-requests.jsonl', 'a', encoding='utf-8') as log:
            log.write(json.dumps(dict(kind=kind, payload=payload)) + '\n')
        # Simulate a finite provider. The separate real-Llama probe verifies the
        # same failure using its actual tokenizer and 16384-token context.
        if native and sum(len(str(m.get('content', '')).encode()) for m in messages) > 12000:
            self.counts['native_overflow'] += 1
            self.send_json({'error': {'code': 'exceed_context_size_error',
                           'message': '[exceed_context_size_error] request exceeds the available context size'}}, 400)
            return
        if 'FAIL_SUMMARY' in json.dumps(messages) and summary:
            self.counts['summary_failure'] += 1
            self.send_json({'error': {'code': 'provider_failure', 'message': 'Intentional summarization failure'}}, 500)
            return
        if not summary and payload.get('max_tokens') != 256:
            self.send_error(400, 'Response reserve was not propagated')
            return
        if summary and payload.get('tools'):
            self.send_error(400, 'Summarization must not execute tools')
            return
        text = 'Goal: track ORDER-42. Inventory verified; delivery pending.' if summary else 'ORDER-42 pending. ' * 60
        if native:
            text = json.dumps({'timestamp': 'oldest to newest', 'user_goals': 'Track ORDER-42',
                               'facts_learned': ['Inventory verified; delivery pending.'],
                               'tool_actions': [], 'decisions': [], 'next_steps': ['Check delivery'],
                               'constraints': '', 'open_questions': []})
        result = {'id': 'context-test', 'object': 'chat.completion', 'created': 1,
                  'model': payload['model'], 'choices': [{'index': 0, 'finish_reason': 'stop',
                  'message': {'role': 'assistant', 'content': text}}],
                  'usage': {'prompt_tokens': 20, 'completion_tokens': 200, 'total_tokens': 220}}
        self.send_json(result)

    def log_message(self, *_):
        pass


ThreadingHTTPServer(('127.0.0.1', 18091), Handler).serve_forever()
