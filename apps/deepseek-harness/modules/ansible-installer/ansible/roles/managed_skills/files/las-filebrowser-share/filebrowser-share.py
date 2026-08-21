#!/usr/bin/env python3
import argparse
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
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        fail(f"FileBrowser API request failed: HTTP {exc.code}: {detail[:500]}")
    except (URLError, OSError) as exc:
        fail(f"FileBrowser API request failed: {exc}")
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        fail("FileBrowser returned invalid JSON")


def emit(response):
    print(json.dumps(response, separators=(",", ":")))


def positive_integer(value):
    if not value.isdigit() or int(value) <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return value


def positive_number(value):
    return int(positive_integer(value))


def share(args):
    payload = {
        "path": args.path,
        "source": SOURCE,
        "shareType": args.share_type,
        "expires": args.expires,
        "unit": args.unit,
        "showHidden": False,
    }
    if args.downloads_limit is not None:
        payload["downloadsLimit"] = args.downloads_limit
    if args.max_bandwidth is not None:
        payload["maxBandwidth"] = args.max_bandwidth
    if args.disable_anonymous_access:
        payload["disableAnonymousAccess"] = True
    if args.keep_after_expiration:
        payload["keepAfterExpiration"] = True
    if args.password_stdin:
        payload["password"] = sys.stdin.read().rstrip("\r\n")
    elif args.password_file:
        try:
            payload["password"] = Path(args.password_file).read_text(encoding="utf-8").rstrip("\r\n")
        except OSError as exc:
            fail(f"unable to read password file: {exc}")
    if "password" in payload and not payload["password"]:
        fail("password must not be empty")
    emit(api("POST", "/api/share", payload))


def list_shares(args):
    if args.path:
        emit(api("GET", "/api/share", query={"source": SOURCE, "path": args.path}))
    else:
        emit(api("GET", "/api/share/list"))


def revoke(args):
    emit(api("DELETE", "/api/share", query={"hash": args.hash}))


def parser():
    command_parser = argparse.ArgumentParser(description="FileBrowser share API client")
    commands = command_parser.add_subparsers(dest="command", required=True)

    share_parser = commands.add_parser("share")
    share_parser.add_argument("--path", required=True)
    share_parser.add_argument("--expires", type=positive_integer, default="2")
    share_parser.add_argument("--unit", choices=("minutes", "hours", "days"), default="hours")
    share_parser.add_argument("--share-type", choices=("normal", "upload"), default="normal")
    share_parser.add_argument("--downloads-limit", type=positive_number)
    share_parser.add_argument("--max-bandwidth", type=positive_number)
    share_parser.add_argument("--disable-anonymous-access", action="store_true")
    share_parser.add_argument("--keep-after-expiration", action="store_true")
    password_group = share_parser.add_mutually_exclusive_group()
    password_group.add_argument("--password-stdin", action="store_true")
    password_group.add_argument("--password-file")
    share_parser.set_defaults(handler=share)

    list_parser = commands.add_parser("list")
    list_parser.add_argument("--path")
    list_parser.set_defaults(handler=list_shares)

    revoke_parser = commands.add_parser("revoke")
    revoke_parser.add_argument("--hash", required=True)
    revoke_parser.set_defaults(handler=revoke)
    return command_parser


def main(argv):
    args = parser().parse_args(argv)
    args.handler(args)


if __name__ == "__main__":
    main(sys.argv[1:])
