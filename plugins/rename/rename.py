#!/usr/bin/env python3
"""Auto-rename Claude Code sessions using directory name + counter.

Reads session_id and cwd from stdin JSON (SessionStart hook payload),
computes a name like "Tools-AI-3", and writes a custom-title entry
to the session JSONL file.

Counter state is stored in ~/.claude/rename/state.json.
"""

import json
import os
import sys
import tempfile

STATE_DIR = os.path.expanduser("~/.claude/rename")
STATE_FILE = os.path.join(STATE_DIR, "state.json")
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")


def read_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def write_state(state):
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    tmpfd, tmppath = tempfile.mkstemp(dir=STATE_DIR, suffix=".tmp")
    try:
        with os.fdopen(tmpfd, "w") as f:
            json.dump(state, f, indent=2)
            f.write("\n")
        os.replace(tmppath, STATE_FILE)
    except Exception:
        try:
            os.unlink(tmppath)
        except OSError:
            pass
        raise


def cwd_to_project_dir(cwd):
    """Convert cwd to Claude's project directory name (replace / with -)."""
    return cwd.replace("/", "-")


def find_session_jsonl(session_id, cwd):
    """Find the session JSONL file path."""
    project_dir_name = cwd_to_project_dir(cwd)
    jsonl_path = os.path.join(PROJECTS_DIR, project_dir_name, session_id + ".jsonl")
    if os.path.exists(jsonl_path):
        return jsonl_path
    # Fallback: search project dirs for the session file
    if os.path.isdir(PROJECTS_DIR):
        for d in os.listdir(PROJECTS_DIR):
            candidate = os.path.join(PROJECTS_DIR, d, session_id + ".jsonl")
            if os.path.exists(candidate):
                return candidate
    return jsonl_path  # Return expected path even if not found yet


def write_custom_title(jsonl_path, session_id, title):
    """Append a custom-title entry to the session JSONL file."""
    entry = {"type": "custom-title", "customTitle": title, "sessionId": session_id}
    with open(jsonl_path, "a") as f:
        f.write(json.dumps(entry) + "\n")


def main():
    # Read hook payload from stdin
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    session_id = payload.get("session_id", "")
    cwd = payload.get("cwd", "")

    if not session_id or not cwd:
        sys.exit(0)

    # Compute directory basename for the name
    dirname = os.path.basename(cwd)
    if not dirname:
        sys.exit(0)

    # Read and increment counter
    state = read_state()
    counter = state.get(cwd, 0) + 1
    state[cwd] = counter
    write_state(state)

    # Generate title
    title = f"{dirname}-{counter}"

    # Write custom-title to session JSONL
    jsonl_path = find_session_jsonl(session_id, cwd)
    try:
        write_custom_title(jsonl_path, session_id, title)
    except FileNotFoundError:
        # Session file may not exist yet; create directory and retry
        os.makedirs(os.path.dirname(jsonl_path), exist_ok=True)
        write_custom_title(jsonl_path, session_id, title)

    # Output confirmation (added to Claude's context)
    print(f"Session renamed to: {title}")


if __name__ == "__main__":
    main()
