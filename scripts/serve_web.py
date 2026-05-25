#!/usr/bin/env python3
"""Static file server for local web testing.

Serves the built Flutter web bundle (packages/totem_web/build/web) with the
headers the assets need when the HTML document is served from a *different*
origin than the assets -- which is the production topology this project targets:
Django serves the /room/ HTML, and the assets are fetched from a CDN via
ASSET_BASE. Locally that means e.g. Django at http://localhost:8000 and this
server (the "CDN") at http://localhost:5173.

The stock `python3 -m http.server` sends no CORS headers, so those cross-origin
asset fetches get blocked. This adds:

  - Access-Control-Allow-Origin: *          so the document origin may fetch assets
  - Cross-Origin-Resource-Policy: cross-origin  so a COEP-isolated page may embed them

Usage: python3 scripts/serve_web.py [port] [directory]
"""

import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class CORSRequestHandler(SimpleHTTPRequestHandler):
    # Make sure wasm/js are served with the right MIME on every Python version.
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
    }

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5173
    directory = sys.argv[2] if len(sys.argv) > 2 else "packages/totem_web/build/web"
    handler = partial(CORSRequestHandler, directory=directory)
    print(f"Serving {directory} at http://localhost:{port}/ (CORS enabled)")
    try:
        ThreadingHTTPServer(("0.0.0.0", port), handler).serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
