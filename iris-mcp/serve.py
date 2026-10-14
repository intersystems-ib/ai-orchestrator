"""Expose the bundled MCP 2.0 server to explicitly allowed Docker hostnames.

This binary's underlying HTTP library accepts loopback Host headers only and
does not expose its allow-list in TOML. Keep it on loopback and validate the
external Host here before forwarding to its loopback authority.
"""
import http.client
import http.server
import signal
import subprocess
import threading
import tomllib
import urllib.parse

with open('/etc/iris-mcp/config.toml', 'rb') as config_file:
    configuration = tomllib.load(config_file)
allowed_hosts = {host.lower() for host in configuration['mcp']['allowed_hosts']}
route = configuration['mcp'].get('base_route', '/mcp')
upstream_port = configuration['mcp']['port']
hop_headers = {'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
               'te', 'trailer', 'transfer-encoding', 'upgrade', 'host', 'content-length'}


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def relay(self):
        authority = self.headers.get('Host', '').lower()
        hostname = urllib.parse.urlsplit('//' + authority).hostname
        if authority not in allowed_hosts and hostname not in allowed_hosts:
            self.send_error(403, 'Host is not allowed')
            return
        if self.path.split('?', 1)[0] != route:
            self.send_error(404)
            return
        if self.headers.get('Transfer-Encoding'):
            self.send_error(400, 'Send Content-Length')
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            self.send_error(400)
            return
        if length < 0 or length > 4 * 1024 * 1024:
            self.send_error(413)
            return
        self.connection.settimeout(65)
        body = self.rfile.read(length) if length else None
        connection = http.client.HTTPConnection('127.0.0.1', upstream_port, timeout=65)
        started = False
        try:
            headers = {key: value for key, value in self.headers.items() if key.lower() not in hop_headers}
            headers['Host'] = f'localhost:{upstream_port}'
            connection.request(self.command, self.path, body=body, headers=headers)
            response = connection.getresponse()
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in hop_headers:
                    self.send_header(key, value)
            has_body = response.status not in (204, 304) and not 100 <= response.status < 200
            if has_body:
                self.send_header('Transfer-Encoding', 'chunked')
            else:
                self.send_header('Content-Length', '0')
            self.end_headers()
            started = True
            if has_body:
                while True:
                    chunk = response.read1(65536)
                    if not chunk:
                        break
                    self.wfile.write(f'{len(chunk):X}\r\n'.encode() + chunk + b'\r\n')
                    self.wfile.flush()
                self.wfile.write(b'0\r\n\r\n')
                self.wfile.flush()
        except (OSError, http.client.HTTPException):
            self.close_connection = True
            if not started:
                self.send_error(502, 'MCP transport unavailable')
        finally:
            connection.close()

    do_POST = do_GET = do_DELETE = do_OPTIONS = relay

    def log_message(self, format, *args):
        # Avoid logging Authorization, tool arguments, and server responses.
        pass


if __name__ == '__main__':
    child = subprocess.Popen(['/usr/irissys/bin/iris-mcp-server', '--config',
                              '/etc/iris-mcp/config.toml', 'run'])
    server = http.server.ThreadingHTTPServer(('0.0.0.0', 8080), Handler)
    server.daemon_threads = True

    def stop(signum=None, frame=None):
        child.terminate()
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def monitor():
        child.wait()
        server.shutdown()

    threading.Thread(target=monitor, daemon=True).start()
    try:
        server.serve_forever()
    finally:
        server.server_close()
        if child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        if child.returncode:
            raise SystemExit(child.returncode)
