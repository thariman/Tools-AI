#!/usr/bin/env python3
"""Claude Code Update Checker — Python fallback (no Node.js required)
Checks npm registry for newer versions, fetches GitHub release notes,
caches results to ~/.claude/statusline/update-cache.json.
Uses urllib (stdlib) for HTTP, falls back to curl."""
import sys, os, json, re, time, subprocess

CACHE_DIR = os.path.join(os.path.expanduser('~'), '.claude', 'statusline')
CACHE_FILE = os.path.join(CACHE_DIR, 'update-cache.json')
CHECK_INTERVAL_MS = 4 * 3600 * 1000  # 4 hours in ms


def read_cache():
    try:
        with open(CACHE_FILE) as f:
            return json.load(f)
    except Exception:
        return None


def write_cache(data):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(CACHE_FILE, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
    except Exception:
        pass


def get_current_version():
    """Find current Claude Code version via binary or install metadata."""
    home = os.path.expanduser('~')

    # 1. Try claude/claude-code in PATH
    for cmd in [['claude', '--version'], ['claude-code', '--version']]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            m = re.search(r'(\d+\.\d+\.\d+)', r.stdout)
            if m:
                return m.group(1)
        except Exception:
            pass

    # 2. Try common binary locations
    for p in [
        os.path.join(home, '.local', 'bin', 'claude'),
        os.path.join(home, '.npm-global', 'bin', 'claude'),
        os.path.join(home, '.local', 'share', 'nodeenv', 'bin', 'claude'),
        os.path.join(home, '.volta', 'bin', 'claude'),
        '/usr/local/bin/claude',
        '/usr/bin/claude',
        '/opt/homebrew/bin/claude',
    ]:
        if os.path.isfile(p) and os.access(p, os.X_OK):
            try:
                r = subprocess.run([p, '--version'], capture_output=True, text=True, timeout=5)
                m = re.search(r'(\d+\.\d+\.\d+)', r.stdout)
                if m:
                    return m.group(1)
            except Exception:
                pass

    # 3. Try reading version symlink (native installer layout)
    # ~/.local/bin/claude -> ~/.local/share/claude/versions/X.Y.Z
    link = os.path.join(home, '.local', 'bin', 'claude')
    try:
        target = os.readlink(link)
        m = re.search(r'(\d+\.\d+\.\d+)', target)
        if m:
            return m.group(1)
    except Exception:
        pass

    return None


def fetch_json(url):
    """Fetch JSON from URL using urllib, falling back to curl."""
    # Try urllib first
    try:
        import urllib.request
        req = urllib.request.Request(
            url, headers={'User-Agent': 'claude-code-statusline-plugin/1.0'}
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            return json.loads(resp.read().decode())
    except Exception:
        pass
    # Fall back to curl
    try:
        r = subprocess.run(
            ['curl', '-sf', '-H', 'User-Agent: claude-code-statusline-plugin/1.0', url],
            capture_output=True, text=True, timeout=10,
        )
        if r.returncode == 0 and r.stdout.strip():
            return json.loads(r.stdout)
    except Exception:
        pass
    return None


def is_newer(latest, current):
    l = [int(x) for x in latest.split('.')]
    c = [int(x) for x in current.split('.')]
    for i in range(3):
        lv = l[i] if i < len(l) else 0
        cv = c[i] if i < len(c) else 0
        if lv > cv:
            return True
        if lv < cv:
            return False
    return False


def format_notification(cache):
    if not cache or not cache.get('has_update'):
        return ''
    msg = f'\u2b06 Claude Code v{cache["latest_version"]} is available! (current: v{cache["current_version"]})'
    notes = cache.get('release_notes', '')
    if notes:
        msg += f'\n\nWhat\'s new in v{cache["latest_version"]}:\n{notes}'
    return msg


def main():
    try:
        now = time.time() * 1000  # ms to match JS cache format

        # Check cooldown
        cache = read_cache()
        if cache and cache.get('checked_at') and (now - cache['checked_at'] < CHECK_INTERVAL_MS):
            msg = format_notification(cache)
            if msg:
                sys.stdout.write(msg + '\n')
            return

        current = get_current_version()
        if not current:
            write_cache({'checked_at': now, 'error': 'cannot determine current version'})
            return

        # Fetch latest from npm dist-tags
        tags = fetch_json(
            'https://registry.npmjs.org/-/package/@anthropic-ai/claude-code/dist-tags'
        )
        if not tags or not tags.get('latest'):
            write_cache({
                'checked_at': now,
                'current_version': current,
                'error': 'npm fetch failed',
            })
            return

        latest = tags['latest']
        has_update = is_newer(latest, current)
        release_notes = ''

        if has_update:
            # Try GitHub releases (v-prefixed and plain tags)
            for tag in [f'v{latest}', latest]:
                data = fetch_json(
                    f'https://api.github.com/repos/anthropics/claude-code/releases/tags/{tag}'
                )
                if data and data.get('body'):
                    release_notes = data['body']
                    break

            # Try "latest" endpoint as last resort
            if not release_notes:
                data = fetch_json(
                    'https://api.github.com/repos/anthropics/claude-code/releases/latest'
                )
                if (data and data.get('body')
                        and data.get('tag_name', '').lstrip('v') == latest):
                    release_notes = data['body']

            if len(release_notes) > 1500:
                release_notes = release_notes[:1500] + '\n\u2026(truncated)'

        result = {
            'checked_at': now,
            'current_version': current,
            'latest_version': latest,
            'has_update': has_update,
            'release_notes': release_notes,
        }
        write_cache(result)

        msg = format_notification(result)
        if msg:
            sys.stdout.write(msg + '\n')
    except Exception:
        pass


if __name__ == '__main__':
    main()
