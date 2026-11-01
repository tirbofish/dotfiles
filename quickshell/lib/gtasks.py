#!/usr/bin/env python3
"""Two-way sync of the desktop todo list with Google Tasks (default list) via `gws`.

argv[1]: {"todos": [{id, text, done, updated?, gid?}], "deleted": [gid, ...]}
stdout:  {"todos": [...merged...], "deleted": [gids handled]}
Prints nothing on stdout if Google can't be reached, so local state is untouched.
"""
import json, os, shutil, subprocess, sys
from datetime import datetime

LIST = "@default"
GWS = shutil.which("gws") or os.path.expanduser("~/.bun/bin/gws")


def gws(method, params, body=None):
    cmd = [GWS, "tasks", "tasks", method, "--params", json.dumps({"tasklist": LIST, **params})]
    if body is not None:
        cmd += ["--json", json.dumps(body)]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if p.returncode != 0:
        raise RuntimeError(f"gws {method}: {p.stderr.strip() or p.stdout.strip()}")
    out = p.stdout.strip()
    return json.loads(out) if out else {}


def ms(iso):
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def status(done):
    return {"status": "completed" if done else "needsAction"}


def sync(todos, deleted):
    # ponytail: first 100 tasks only; add pageToken looping if the list grows past that
    items = gws("list", {"showCompleted": True, "showHidden": False, "maxResults": 100}).get("items", [])
    remote = {r["id"]: r for r in items if r.get("title")}

    for gid in deleted:
        if remote.pop(gid, None):
            gws("delete", {"task": gid})

    out = []
    for t in todos:
        gid = t.get("gid")
        if not gid:
            try:
                r = gws("insert", {}, {"title": t["text"], **status(t.get("done"))})
                t = {**t, "gid": r["id"], "updated": ms(r["updated"])}
            except RuntimeError as e:
                print(e, file=sys.stderr)  # stays local, retried next sync
            out.append(t)
            continue
        r = remote.pop(gid, None)
        if r is None:
            continue  # deleted or cleared in Google
        rdone = r.get("status") == "completed"
        if r["title"] != t["text"] or rdone != bool(t.get("done")):
            if t.get("updated", 0) > ms(r["updated"]):
                gws("patch", {"task": gid}, {"title": t["text"], **status(t.get("done"))})
            else:
                t = {**t, "text": r["title"], "done": rdone, "updated": ms(r["updated"])}
        out.append(t)

    for r in sorted(remote.values(), key=lambda r: r.get("position", "")):
        out.append({"id": "g_" + r["id"], "gid": r["id"], "text": r["title"],
                    "done": r.get("status") == "completed", "updated": ms(r["updated"])})
    return out


if __name__ == "__main__":
    data = json.loads(sys.argv[1])
    try:
        todos = sync(data.get("todos", []), data.get("deleted", []))
    except Exception as e:
        sys.exit(f"sync failed: {e}")
    print(json.dumps({"todos": todos, "deleted": data.get("deleted", [])}))
