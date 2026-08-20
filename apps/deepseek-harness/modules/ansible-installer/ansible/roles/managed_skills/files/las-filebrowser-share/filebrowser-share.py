#!/usr/bin/env python3
import hashlib
import json
import os
import secrets
import shutil
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError


def fail(message):
    print(json.dumps({"error": message}, ensure_ascii=True), file=sys.stderr)
    raise SystemExit(2)


def required_env(name):
    value = os.environ.get(name)
    if not value:
        fail(f"missing required environment variable: {name}")
    return value


API_BASE = required_env("LAS_FILEBROWSER_API_BASE")
ROOT = Path(required_env("LAS_FILEBROWSER_ROOT"))
WORKSPACE = Path(required_env("LAS_FILEBROWSER_WORKSPACE"))
SOURCE = required_env("LAS_FILEBROWSER_SOURCE")
TOKEN_FILE = Path(required_env("LAS_FILEBROWSER_TOKEN_FILE"))
STATE_DIR = Path(required_env("LAS_FILEBROWSER_STATE_DIR"))
REGISTRY = STATE_DIR / "managed-shares.json"
INBOX_ROOT = WORKSPACE / ".filebrowser-inbox"
PROTECTED = {".filebrowser", ".config", ".ssh"}


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
        raise RuntimeError(str(exc)) from exc
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError("FileBrowser returned invalid JSON") from exc


def resolve_path(value):
    try:
        resolved = Path(value).resolve(strict=True)
        relative = resolved.relative_to(ROOT)
    except (OSError, ValueError):
        fail("path does not exist" if not Path(value).exists() else "path must remain under /home/dsh")
    if relative.parts and relative.parts[0] in PROTECTED:
        fail("path is protected from sharing")
    return resolved


def api_path(path):
    return "/" if path == ROOT else "/" + str(path.relative_to(ROOT))


def require_positive(name, value):
    if not value or not value.isdigit() or int(value) <= 0:
        fail(f"{name} must be a positive integer")
    return int(value)


def load_registry():
    try:
        entries = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return []
    return entries if isinstance(entries, list) else []


def save_registry(entries):
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix="managed-shares.", dir=STATE_DIR, text=True)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(entries, stream, separators=(",", ":"))
            stream.write("\n")
        os.replace(temporary, REGISTRY)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def record_share(response, kind):
    if kind == "direct" and str(response.get("status", "")) == "201":
        return
    share_hash = response.get("hash")
    if not isinstance(share_hash, str) or not share_hash:
        return
    entries = [entry for entry in load_registry() if isinstance(entry, dict) and entry.get("hash") != share_hash]
    entries.append({"hash": share_hash, "kind": kind, "path": response.get("path", ""), "expire": response.get("expire", 0)})
    save_registry(entries)


def emit(response, kind):
    record_share(response, kind)
    print(json.dumps(response, separators=(",", ":")))


def share_path(remote_path, share_type, duration, unit="days"):
    body = {"path": remote_path, "source": SOURCE, "shareType": share_type, "expires": str(duration), "unit": unit, "showHidden": False, "disableAnonymous": False, "allowCreate": share_type == "upload", "allowModify": False, "allowDelete": False, "allowReplacements": False, "disableDownload": share_type == "upload", "disableFileViewer": share_type == "upload"}
    try:
        response = api("POST", "/api/share", body)
    except RuntimeError:
        fail("FileBrowser share creation failed")
    emit(response, share_type)


def search_files(query, limit):
    if not query:
        fail("search query must be provided")
    limit = require_positive("limit", limit)
    results = []
    query_folded = query.casefold()
    for directory, dirnames, filenames in os.walk(ROOT, followlinks=False):
        dirnames[:] = sorted(name for name in dirnames if name not in PROTECTED and not os.path.islink(os.path.join(directory, name)))
        for name in sorted(dirnames + filenames):
            if query_folded not in name.casefold():
                continue
            path = Path(directory) / name
            try:
                info = path.lstat()
            except OSError:
                continue
            if path.is_symlink():
                continue
            results.append({"path": str(path), "type": "directory" if path.is_dir() else "file", "size": info.st_size, "mtime": int(info.st_mtime)})
            if len(results) >= limit:
                print(json.dumps({"query": query, "results": results, "truncated": True}, sort_keys=True))
                return
    print(json.dumps({"query": query, "results": results, "truncated": False}, sort_keys=True))


def list_managed(response, path_filter=""):
    hashes = {entry.get("hash") for entry in load_registry() if isinstance(entry, dict)}
    items = response if isinstance(response, list) else []
    filtered = []
    for item in items:
        if not isinstance(item, dict) or item.get("hash") not in hashes:
            continue
        if path_filter and item.get("path", "") != path_filter:
            continue
        item = dict(item)
        item.pop("token", None)
        item.pop("password_hash", None)
        filtered.append(item)
    print(json.dumps(filtered, sort_keys=True))


def inspect_path(path):
    info = path.stat()
    print(json.dumps({"path": str(path), "type": "directory" if path.is_dir() else "file", "size": info.st_size, "mode": oct(info.st_mode & 0o777), "mtime": int(info.st_mtime)}, sort_keys=True))


def checksum(path):
    if not path.is_file():
        fail("checksum requires a file")
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    print(json.dumps({"path": str(path), "sha256": digest.hexdigest()}, sort_keys=True))


def archive(paths, days):
    days = require_positive("days", days)
    remote_paths = [api_path(resolve_path(path)) for path in paths]
    archive_remote_path = f"{api_path(WORKSPACE)}/filebrowser-archive-{secrets.token_hex(8)}.tar.gz"
    body = {"fromSource": SOURCE, "toSource": SOURCE, "paths": remote_paths, "destination": archive_remote_path, "format": "tar.gz", "deleteAfter": False}
    try:
        api("POST", "/api/resources/archive", body)
    except RuntimeError:
        fail("FileBrowser archive creation failed")
    share_path(archive_remote_path, "normal", days)


def revoke(share_hash):
    if not share_hash or len(share_hash) < 8 or len(share_hash) > 128 or not all(char.isalnum() or char in "_-" for char in share_hash):
        fail("invalid share hash")
    entries = load_registry()
    entry = next((item for item in entries if isinstance(item, dict) and item.get("hash") == share_hash), None)
    if entry is None:
        fail("share is not managed by this helper")
    try:
        api("DELETE", "/api/share", query={"hash": share_hash})
    except RuntimeError:
        fail("FileBrowser share revoke failed")
    save_registry([item for item in entries if not (isinstance(item, dict) and item.get("hash") == share_hash)])
    if entry.get("kind") == "direct":
        path = entry.get("path", "")
        if isinstance(path, str) and path.startswith("/"):
            staging_file = (ROOT / path.lstrip("/")).resolve()
            if staging_file.parent == WORKSPACE.resolve() and staging_file.name.startswith("filebrowser-direct-") and staging_file.is_file():
                staging_file.unlink()
    print('{"revoked":true}')


def main(argv):
    if not argv:
        fail("missing operation")
    action, args = argv[0], argv[1:]
    if action == "inspect":
        if len(args) != 1: fail("inspect requires PATH")
        inspect_path(resolve_path(args[0]))
    elif action == "checksum":
        if len(args) != 1: fail("checksum requires PATH")
        checksum(resolve_path(args[0]))
    elif action == "search":
        if len(args) not in (1, 2): fail("search requires QUERY [LIMIT]")
        search_files(args[0], args[1] if len(args) == 2 else "50")
    elif action == "direct":
        if len(args) != 2: fail("direct requires PATH MINUTES")
        path = resolve_path(args[0])
        if not path.is_file(): fail("direct requires a file")
        minutes = require_positive("minutes", args[1])
        staging_file = WORKSPACE / f"filebrowser-direct-{secrets.token_hex(8)}-{path.name}"
        shutil.copy2(path, staging_file)
        staging_file.chmod(0o600)
        try:
            response = api("POST", "/api/share", {"path": api_path(staging_file), "source": SOURCE, "shareType": "normal", "expires": args[1], "unit": "minutes", "showHidden": False, "disableAnonymous": False, "allowCreate": False, "allowModify": False, "allowDelete": False, "allowReplacements": False, "disableDownload": False, "disableFileViewer": False})
        except RuntimeError:
            staging_file.unlink(missing_ok=True)
            fail("FileBrowser direct link creation failed")
        response["status"] = "200"
        response["url"] = response.get("downloadURL", "") + "&file=" + quote(path.name)
        emit(response, "direct")
    elif action == "share":
        if len(args) != 2: fail("share requires PATH DAYS")
        require_positive("days", args[1]); share_path(api_path(resolve_path(args[0])), "normal", args[1])
    elif action == "inbox":
        if len(args) != 1: fail("inbox requires DAYS")
        days = require_positive("days", args[0])
        INBOX_ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
        inbox = Path(tempfile.mkdtemp(prefix="inbox.", dir=INBOX_ROOT))
        share_path(api_path(inbox), "upload", args[0])
    elif action == "archive":
        if len(args) < 3: fail("archive requires PATH [PATH ...] --days DAYS")
        if "--days" not in args: fail("archive requires DAYS")
        marker = args.index("--days")
        if marker == 0 or marker == len(args) - 1: fail("archive requires PATH [PATH ...] --days DAYS")
        archive(args[:marker], args[marker + 1])
    elif action == "list":
        if len(args) > 1: fail("list accepts optional PATH")
        path_filter = ""
        try:
            if args:
                path_filter = api_path(resolve_path(args[0]))
                response = api("GET", "/api/share", query={"source": SOURCE, "path": path_filter})
            else:
                response = api("GET", "/api/share/list")
        except RuntimeError:
            fail("FileBrowser share list failed")
        list_managed(response, path_filter)
    elif action == "revoke":
        if len(args) != 1: fail("revoke requires HASH")
        revoke(args[0])
    else:
        fail("unsupported operation")


if __name__ == "__main__":
    main(sys.argv[1:])
