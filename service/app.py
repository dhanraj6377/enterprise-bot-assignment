import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from socket import gethostname

APP_NAME = os.getenv("APP_NAME", "demo")
VERSION = os.getenv("VERSION", "0.0.0")
PORT = int(os.getenv("PORT", "8080"))


class DemoHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return

        if self.path == "/":
            payload = {
                "app": APP_NAME,
                "version": VERSION,
                "pod": gethostname(),
            }
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), DemoHandler)
    print(f"Listening on 0.0.0.0:{PORT}")
    server.serve_forever()
