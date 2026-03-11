#!/usr/bin/env python3
"""Claude Code Statusline — Python fallback (no Node.js required)
Shows: model | current task | dir | git branch status | context usage | update"""
import sys, os, json, subprocess


def main():
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        return

    model = (data.get('model') or {}).get('display_name', 'Claude')
    dir_path = (data.get('workspace') or {}).get('current_dir', os.getcwd())
    session = data.get('session_id', '')
    remaining = (data.get('context_window') or {}).get('remaining_percentage')

    # Context window display (shows USED percentage)
    ctx = ''
    if remaining is not None:
        rem = round(remaining)
        used = 100 - rem
        filled = used // 10
        bar = '\u2588' * filled + '\u2591' * (10 - filled)
        if used < 50:
            ctx = f' \033[32m{bar} {used}%\033[0m'
        elif used < 65:
            ctx = f' \033[33m{bar} {used}%\033[0m'
        elif used < 80:
            ctx = f' \033[38;5;208m{bar} {used}%\033[0m'
        else:
            ctx = f' \033[5;31m\U0001f480 {bar} {used}%\033[0m'

    # Current task from todos
    task = ''
    home = os.path.expanduser('~')
    todos_dir = os.path.join(home, '.claude', 'todos')
    if session and os.path.isdir(todos_dir):
        try:
            files = [
                f for f in os.listdir(todos_dir)
                if f.startswith(session) and '-agent-' in f and f.endswith('.json')
            ]
            if files:
                files.sort(
                    key=lambda f: os.path.getmtime(os.path.join(todos_dir, f)),
                    reverse=True,
                )
                with open(os.path.join(todos_dir, files[0])) as fh:
                    todos = json.load(fh)
                ip = next((t for t in todos if t.get('status') == 'in_progress'), None)
                if ip:
                    task = ip.get('activeForm', '')
        except Exception:
            pass

    # Version update indicator
    update = ''
    try:
        cache_file = os.path.join(home, '.claude', 'statusline', 'update-cache.json')
        with open(cache_file) as fh:
            cache = json.load(fh)
        if cache.get('has_update') and cache.get('latest_version'):
            update = f' \u2502 \033[35m\u2b06 v{cache["latest_version"]}\033[0m'
    except Exception:
        pass

    # Git status
    git = ''
    try:
        branch = subprocess.run(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            cwd=dir_path, capture_output=True, text=True, timeout=3,
        ).stdout.strip()
        if branch:
            porcelain = subprocess.run(
                ['git', 'status', '--porcelain'],
                cwd=dir_path, capture_output=True, text=True, timeout=3,
            ).stdout.strip()
            indicator = ' \033[33m\u25cf\033[0m' if porcelain else ' \033[32m\u2714\033[0m'
            git = f' \u2502 \033[36m{branch}\033[0m{indicator}'
    except Exception:
        pass

    # Output
    dirname = os.path.basename(dir_path)
    if task:
        sys.stdout.write(
            f'\033[2m{model}\033[0m \u2502 \033[1m{task}\033[0m'
            f' \u2502 \033[2m{dirname}\033[0m{git}{ctx}{update}'
        )
    else:
        sys.stdout.write(
            f'\033[2m{model}\033[0m \u2502 \033[2m{dirname}\033[0m{git}{ctx}{update}'
        )


if __name__ == '__main__':
    main()
