#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def fail(message):
    print(json.dumps({"error": message}, ensure_ascii=True), file=sys.stderr)
    raise SystemExit(2)


def required_env(name):
    value = os.environ.get(name)
    if not value:
        fail(f"missing required environment variable: {name}")
    return value


API_BASE = required_env("LAS_FILEBROWSER_API_BASE")
SOURCE = required_env("LAS_FILEBROWSER_SOURCE")
TOKEN_FILE = Path(required_env("LAS_FILEBROWSER_TOKEN_FILE"))


def read_token():
    try:
        token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        fail("FileBrowser agent token is unavailable")
    if not token:
        fail("FileBrowser agent token is empty")
    return token


TOKEN = read_token()


def api(method, path, body=None, query=None):
    if query:
        path = f"{path}?{urlencode(query)}"
    request = Request(f"{API_BASE}{path}", method=method)
    request.add_header("Authorization", f"Bearer {TOKEN}")
    request.add_header("Accept", "application/json")
    if body is not None:
        request.data = json.dumps(body, separators=(",", ":")).encode()
        request.add_header("Content-Type", "application/json")
    try:
        with urlopen(request) as response:
            raw = response.read()
    except (HTTPError, URLError, OSError) as exc:
        fail(f"FileBrowser API request failed: {exc}")
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        fail("FileBrowser returned invalid JSON")


def emit(response):
    print(json.dumps(response, separators=(",", ":")))


def share(args):
    if len(args) > 3 or not args:
        fail("share requires PATH [HOURS] [normal|upload]")
    hours = "2"
    share_type = "normal"
    if len(args) >= 2:
        if args[1] in {"normal", "upload"}:
            share_type = args[1]
        else:
            hours = args[1]
            share_type = args[2] if len(args) == 3 else "normal"
    if share_type not in {"normal", "upload"}:
        fail("share type must be normal or upload")
    if not hours.isdigit() or int(hours) <= 0:
        fail("hours must be a positive integer")
    emit(api("POST", "/api/share", {
        "path": args[0],
        "source": SOURCE,
        "shareType": share_type,
        "expires": hours,
        "unit": "hours",
        "showHidden": False,
    }))


def list_shares(args):
    if len(args) > 1:
        fail("list accepts optional PATH")
    if args:
        emit(api("GET", "/api/share", query={"source": SOURCE, "path": args[0]}))
    else:
        emit(api("GET", "/api/share/list"))


def revoke(args):
    if len(args) != 1 or not args[0]:
        fail("revoke requires HASH")
    emit(api("DELETE", "/api/share", query={"hash": args[0]}))


def main(argv):
    if not argv:
        fail("missing operation")
    action, args = argv[0], argv[1:]
    if action == "share":
        share(args)
    elif action == "list":
        list_shares(args)
    elif action == "revoke":
        revoke(args)
    else:
        fail("unsupported operation; use share, list, or revoke")


if __name__ == "__main__":
    main(sys.argv[1:])
