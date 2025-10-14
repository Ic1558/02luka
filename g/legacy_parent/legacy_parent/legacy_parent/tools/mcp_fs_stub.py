#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/health'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True, "service": "mcp_fs_stub"}).encode())
        elif self.path.startswith('/mcp/manifest'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "name": "mcp_fs_stub",
                "version": "0.0.1",
                "resources": ["repo"],
                "tools": ["list","read"]
            }).encode())
        else:
            self.send_response(404)
            self.end_headers()
    def log_message(self, format, *args):
        return

if __name__ == '__main__':
    addr = ('0.0.0.0', 8765)
    httpd = HTTPServer(addr, Handler)
    httpd.serve_forever()
