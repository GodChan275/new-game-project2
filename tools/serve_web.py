"""Serve the HTML5 export in build/web for local testing.

A plain file:// open cannot load the exported .wasm/.pck modules, so this
starts a small HTTP server with the right MIME types (notably application/wasm).

Run: python tools/serve_web.py [port]      (default 8099)
Then open http://127.0.0.1:<port>/index.html
"""
import functools
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".pck": "application/octet-stream",
        ".html": "text/html",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


def main() -> None:
    if not os.path.isfile(os.path.join(ROOT, "index.html")):
        print("No export found in %s -- run the Web export first." % ROOT)
        raise SystemExit(1)
    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", PORT), functools.partial(Handler, directory=ROOT)
    )
    print("Serving %s on http://127.0.0.1:%d/index.html" % (ROOT, PORT), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
