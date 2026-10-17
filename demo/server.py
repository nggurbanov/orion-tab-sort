#!/usr/bin/env python3
"""Loopback-only synthetic demo; serves actual extension sources, never Orion."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parent.parent
class Demo(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.split('?')[0] in ('/', '/demo/', '/demo/index.html'):
            html = (ROOT / 'extension/sorter.html').read_text()
            html = html.replace('href="sorter.css"', 'href="/extension/sorter.css"')
            html = html.replace('src="', 'src="/extension/')
            html = html.replace('<script src="/extension/sorter.js">', '<script src="/demo/transport.js"></script><script src="/extension/sorter.js">')
            html = html.replace('</head>', '<link rel="stylesheet" href="/demo/demo.css"></head>')
            html = html.replace('</body>', '<script src="/demo/controls.js"></script></body>')
            html = html.replace('<head>', '<head><meta http-equiv="Content-Security-Policy" content="default-src \'self\'; script-src \'self\'; connect-src \'none\'; img-src \'none\'; object-src \'none\'; style-src \'self\'; base-uri \'none\'; form-action \'none\'">')
            data = html.encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif self.path.split('?')[0].startswith(('/extension/', '/demo/')):
            super().do_GET()
        else:
            self.send_error(404)

if __name__ == '__main__':
    os.chdir(ROOT)
    print('Synthetic demo: http://127.0.0.1:4877/demo/ (loopback only)', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 4877), Demo).serve_forever()
