"""Local static file server for admin_web with explicit JS/CSS MIME types on Windows."""

from __future__ import annotations

import argparse
from functools import partial
import http.server
import mimetypes
from pathlib import Path
import sys


def _configure_mimetypes() -> dict[str, str]:
    """Ensure .js/.mjs/.css/.svg/.json serve with standard web MIME types on Windows."""
    overrides = {
        ".js": "application/javascript; charset=utf-8",
        ".mjs": "application/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8",
        ".html": "text/html; charset=utf-8",
        ".svg": "image/svg+xml",
        ".json": "application/json; charset=utf-8",
    }
    for ext, mime in overrides.items():
        mimetypes.add_type(mime, ext)
    return {**http.server.SimpleHTTPRequestHandler.extensions_map, **overrides}


class AdminWebHandler(http.server.SimpleHTTPRequestHandler):
    """Static handler overriding Windows registry text/plain MIME quirks for .js files."""

    extensions_map = _configure_mimetypes()

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Serve admin_web locally for development.")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8080, help="Bind port (default: 8080)")
    args = parser.parse_args(argv)

    root_dir = Path(__file__).resolve().parent
    handler_cls = partial(AdminWebHandler, directory=str(root_dir))
    server = http.server.ThreadingHTTPServer((args.host, args.port), handler_cls)

    print(f"Serving admin_web from {root_dir}")
    print(f"Open: http://localhost:{args.port}/")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local admin_web server.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
