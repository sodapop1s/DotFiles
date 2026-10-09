#!/usr/bin/env python3
"""One-time Spotify login for the Quickshell bar.

  spotify-login.py login   -> one-time browser login (PKCE); prints the URL to open.
                              Needs python3 (e.g. `nix shell nixpkgs#python3 -c python3 spotify-login.py login`).
Everyday use (playlists, play) is spotify.sh, which only needs bash, curl and jq.

Uses the app whose client id is in ~/.config/spotify-player/app.toml, with its own login
stored in ~/.local/state/qs-bar-spotify.json. spotify_player's saved token is not used:
Spotify rotates refresh tokens, so two programs sharing one would invalidate each other.
"""
import base64, hashlib, http.server, json, os, re, secrets, sys, time, urllib.error, urllib.parse, urllib.request

HOME = os.path.expanduser("~")
STATE = os.path.join(HOME, ".local/state/qs-bar-spotify.json")
SP_CONF = os.path.join(HOME, ".config/spotify-player/app.toml")
DEVICE_NAME = "spotify-player"
REDIRECT = "http://127.0.0.1:8989/login"
SCOPES = "playlist-read-private playlist-read-collaborative user-read-playback-state user-modify-playback-state user-read-currently-playing user-library-read user-library-modify"


def fail(msg, code=1):
    print(json.dumps({"error": msg}))
    sys.exit(code)


def client_id():
    try:
        m = re.search(r'^client_id\s*=\s*"([^"]+)"', open(SP_CONF).read(), re.M)
        if m:
            return m.group(1)
    except OSError:
        pass
    fail("no client_id in spotify-player app.toml")


def save_state(st):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    fd = os.open(STATE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(st, f)


def load_state():
    try:
        return json.load(open(STATE))
    except (OSError, ValueError):
        fail("not logged in: run `spotify.py login`")


def login():
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(12)
    url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode({
        "client_id": client_id(), "response_type": "code", "redirect_uri": REDIRECT,
        "scope": SCOPES, "state": state, "code_challenge_method": "S256", "code_challenge": challenge,
    })
    got = {}

    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.urlparse(self.path)
            if q.path != "/login":
                self.send_response(404); self.end_headers(); return
            got.update({k: v[0] for k, v in urllib.parse.parse_qs(q.query).items()})
            self.send_response(200); self.send_header("Content-Type", "text/plain"); self.end_headers()
            self.wfile.write(b"Logged in. You can close this tab.")
        def log_message(self, *a): pass

    srv = http.server.HTTPServer(("127.0.0.1", 8989), H)
    srv.timeout = 1
    print(url, flush=True)
    deadline = time.time() + 300
    while "code" not in got and "error" not in got and time.time() < deadline:
        srv.handle_request()
    if got.get("state") != state or "code" not in got:
        fail("login failed or timed out: %s" % got.get("error", "no code"))
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code", "code": got["code"], "redirect_uri": REDIRECT,
        "client_id": client_id(), "code_verifier": verifier,
    }).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request("https://accounts.spotify.com/api/token", data=data), timeout=10) as r:
            tok = json.load(r)
    except urllib.error.HTTPError as e:
        fail("code exchange failed: %s %s" % (e.code, e.read().decode(errors="replace")[:200]))
    save_state({"refresh_token": tok["refresh_token"], "access_token": tok["access_token"],
                "expires_at": time.time() + int(tok.get("expires_in", 3600))})
    print(json.dumps({"ok": True}))


def access_token():
    st = load_state()
    if st.get("access_token") and st.get("expires_at", 0) > time.time() + 60:
        return st["access_token"]
    data = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": st["refresh_token"],
        "client_id": client_id(),
    }).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request(
                "https://accounts.spotify.com/api/token", data=data), timeout=10) as r:
            tok = json.load(r)
    except urllib.error.HTTPError as e:
        fail("token refresh failed: %s %s" % (e.code, e.read().decode(errors="replace")[:200]))
    except OSError as e:
        fail("network error: %s" % e)
    st["access_token"] = tok["access_token"]
    st["expires_at"] = time.time() + int(tok.get("expires_in", 3600))
    if tok.get("refresh_token"):
        st["refresh_token"] = tok["refresh_token"]
    save_state(st)
    return st["access_token"]


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "login":
        login()
    else:
        fail("usage: spotify-login.py login")
