"""A fake IPTV provider for the emulator (Live pause & rewind tests, dev-notes/live-pause.md):
/list.m3u + /live/clock.ts. Run: python tools/fake_live_ts/live_server.py 8800, then add the
M3U http://10.0.2.2:8800/list.m3u on the emulator (10.0.2.2 = this PC).

Each GET of the .ts starts its own ffmpeg (real time, like a provider): 720p25 test
pattern with the wall clock and the stream's own time burned in, AAC sine, MPEG-TS
with PCR on the video PID and a keyframe every second. Logs every connection so a
test can count how many the player opened.
"""
import datetime
import http.server
import os
import shutil
import socketserver
import tempfile
import subprocess
import sys
import threading

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8800
# ffmpeg runs in a temp folder holding the font (a Windows path's colon needs escaping).
HERE = tempfile.mkdtemp(prefix='fake_live_ts_')
FONT = 'arialbd.ttf'
for f in ('C:/Windows/Fonts/arialbd.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
    if os.path.exists(f):
        shutil.copy(f, os.path.join(HERE, FONT))
        break

connections = 0
lock = threading.Lock()


def log(msg):
    line = f'{datetime.datetime.now():%H:%M:%S} {msg}'
    print(line, flush=True)
    with open(os.path.join(HERE, 'server.log'), 'a', encoding='utf-8') as f:
        f.write(line + '\n')


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.0'

    def log_message(self, *a):
        pass

    def do_GET(self):
        global connections
        if self.path.startswith('/list.m3u'):
            host = self.headers.get('Host', f'10.0.2.2:{PORT}')
            body = ('#EXTM3U\n'
                    '#EXTINF:-1 tvg-id="clock.test" group-title="Test",Test Clock\n'
                    f'http://{host}/live/clock.ts\n').encode()
            self.send_response(200)
            self.send_header('Content-Type', 'audio/x-mpegurl')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if not self.path.startswith('/live/clock.ts'):
            self.send_response(404)
            self.end_headers()
            return
        with lock:
            connections += 1
            n = connections
        log(f'connection {n} opened from {self.client_address[0]} ({self.headers.get("User-Agent")})')
        vf = (f"drawtext=fontfile={FONT}:fontsize=64:fontcolor=white:box=1:boxcolor=black@0.6:"
              f"x=60:y=60:text='%{{localtime\\:%X}}',"
              f"drawtext=fontfile={FONT}:fontsize=40:fontcolor=yellow:box=1:boxcolor=black@0.6:"
              f"x=60:y=150:text='conn {n}  t=%{{pts\\:hms}}'")
        cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-re',
               '-f', 'lavfi', '-i', 'testsrc2=size=1280x720:rate=25',
               '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000',
               '-vf', vf,
               '-c:v', 'libx264', '-preset', 'veryfast', '-tune', 'zerolatency',
               '-b:v', '3000k', '-maxrate', '3000k', '-bufsize', '1500k',
               '-g', '25', '-keyint_min', '25', '-sc_threshold', '0',
               '-c:a', 'aac', '-b:a', '128k',
               '-f', 'mpegts', '-mpegts_flags', '+resend_headers', 'pipe:1']
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, cwd=HERE)
        self.send_response(200)
        self.send_header('Content-Type', 'video/mp2t')
        self.end_headers()
        sent = 0
        try:
            while True:
                chunk = p.stdout.read(64 * 1024)
                if not chunk:
                    break
                self.wfile.write(chunk)
                sent += len(chunk)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass
        finally:
            p.kill()
            log(f'connection {n} closed after {sent / 1048576:.1f} MB')


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == '__main__':
    log(f'listening on {PORT}')
    Server(('0.0.0.0', PORT), Handler).serve_forever()
