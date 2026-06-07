"""Minimal MCP stub server for CI.

Implements just enough of the MCP JSON-RPC protocol for lightspeed-stack
to discover tools and start. Tool calls will fail gracefully — smoke evals
only test response quality, not tool execution.

Uses stdlib only (no pip install needed in python:3.12-slim).
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json


class MCPHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {"status": "ok"})
        elif self.path == "/mcp":
            self._respond(200, {"jsonrpc": "2.0", "result": {"protocolVersion": "2025-03-26", "capabilities": {"tools": {}}}})
        else:
            self._respond(404, {"error": "not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        req_id = body.get("id")
        method = body.get("method", "")

        if method == "initialize":
            result = {
                "protocolVersion": "2025-03-26",
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "mcp-stub", "version": "0.1.0"},
            }
        elif method == "tools/list":
            result = {"tools": []}
        elif method == "notifications/initialized":
            self._respond(200, {"jsonrpc": "2.0", "result": {}})
            return
        else:
            result = {"tools": []}

        self._respond(200, {"jsonrpc": "2.0", "id": req_id, "result": result})

    def _respond(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8000), MCPHandler)
    print("MCP stub listening on port 8000")
    server.serve_forever()
