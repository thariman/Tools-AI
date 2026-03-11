#!/usr/bin/env node
// Claude Code Update Checker
// Checks npm registry for newer versions, fetches GitHub release notes,
// and caches results to ~/.claude/statusline/update-cache.json
// Runs from SessionStart hook — outputs notification if update available.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');
const https = require('https');

const CACHE_DIR = path.join(os.homedir(), '.claude', 'statusline');
const CACHE_FILE = path.join(CACHE_DIR, 'update-cache.json');
const CHECK_INTERVAL_MS = 4 * 3600 * 1000; // 4 hours

function readCache() {
  try {
    return JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
  } catch {
    return null;
  }
}

function writeCache(data) {
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    fs.writeFileSync(CACHE_FILE, JSON.stringify(data, null, 2) + '\n');
  } catch {}
}

function getCurrentVersion() {
  // 1. Try claude in PATH (works when check-update.sh sets up PATH correctly)
  const commands = ['claude --version', 'claude-code --version'];
  for (const cmd of commands) {
    try {
      const output = execSync(cmd, {
        encoding: 'utf8', timeout: 5000,
        stdio: ['pipe', 'pipe', 'pipe'],
      }).trim();
      const match = output.match(/(\d+\.\d+\.\d+)/);
      if (match) return match[1];
    } catch {}
  }

  // 2. Try claude binary at common locations and relative to node
  const homedir = os.homedir();
  const candidatePaths = [
    path.join(path.dirname(process.execPath), 'claude'),  // same dir as node
    path.join(homedir, '.npm-global', 'bin', 'claude'),
    path.join(homedir, '.local', 'share', 'nodeenv', 'bin', 'claude'),
    path.join(homedir, '.volta', 'bin', 'claude'),
    '/usr/local/bin/claude',
    '/usr/bin/claude',
    '/opt/homebrew/bin/claude',
  ];
  for (const p of candidatePaths) {
    try {
      if (!fs.existsSync(p)) continue;
      const output = execSync(`"${p}" --version`, {
        encoding: 'utf8', timeout: 5000,
        stdio: ['pipe', 'pipe', 'pipe'],
      }).trim();
      const match = output.match(/(\d+\.\d+\.\d+)/);
      if (match) return match[1];
    } catch {}
  }

  // 3. Try reading version from npm global package.json
  try {
    const globalRoot = execSync('npm root -g', {
      encoding: 'utf8', timeout: 5000,
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
    const pkgPath = path.join(globalRoot, '@anthropic-ai', 'claude-code', 'package.json');
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    if (pkg.version) return pkg.version;
  } catch {}

  return null;
}

function fetchJSON(url) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      headers: { 'User-Agent': 'claude-code-statusline-plugin/1.0' },
    };
    const req = https.get(opts, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return fetchJSON(res.headers.location).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode}`));
      }
      let body = '';
      res.on('data', chunk => (body += chunk));
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.setTimeout(8000, () => { req.destroy(); reject(new Error('timeout')); });
  });
}

function isNewer(latest, current) {
  const l = latest.split('.').map(Number);
  const c = current.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if ((l[i] || 0) > (c[i] || 0)) return true;
    if ((l[i] || 0) < (c[i] || 0)) return false;
  }
  return false;
}

function formatNotification(cache) {
  if (!cache || !cache.has_update) return '';
  let msg = `\u2b06 Claude Code v${cache.latest_version} is available! (current: v${cache.current_version})`;
  if (cache.release_notes) {
    msg += `\n\nWhat's new in v${cache.latest_version}:\n${cache.release_notes}`;
  }
  return msg;
}

async function main() {
  try {
    // Check cooldown — re-display cached notification but skip network
    const cache = readCache();
    if (cache && cache.checked_at && (Date.now() - cache.checked_at < CHECK_INTERVAL_MS)) {
      const msg = formatNotification(cache);
      if (msg) process.stdout.write(msg + '\n');
      return;
    }

    const currentVersion = getCurrentVersion();
    if (!currentVersion) {
      writeCache({ checked_at: Date.now(), error: 'cannot determine current version' });
      return;
    }

    // Fetch latest version from npm dist-tags
    let latestVersion;
    try {
      const tags = await fetchJSON(
        'https://registry.npmjs.org/-/package/@anthropic-ai/claude-code/dist-tags'
      );
      latestVersion = tags.latest;
    } catch {
      writeCache({
        checked_at: Date.now(),
        current_version: currentVersion,
        error: 'npm registry unreachable',
      });
      return;
    }

    if (!latestVersion) {
      writeCache({
        checked_at: Date.now(),
        current_version: currentVersion,
        error: 'no latest tag found',
      });
      return;
    }

    const hasUpdate = isNewer(latestVersion, currentVersion);
    let releaseNotes = '';

    if (hasUpdate) {
      // Try GitHub releases API (try both v-prefixed and plain tags)
      for (const tag of [`v${latestVersion}`, latestVersion]) {
        try {
          const release = await fetchJSON(
            `https://api.github.com/repos/anthropics/claude-code/releases/tags/${tag}`
          );
          if (release.body) {
            releaseNotes = release.body;
            break;
          }
        } catch {}
      }

      // Also try "latest" endpoint if tag lookup failed
      if (!releaseNotes) {
        try {
          const release = await fetchJSON(
            'https://api.github.com/repos/anthropics/claude-code/releases/latest'
          );
          if (release.body && release.tag_name) {
            const tagVer = release.tag_name.replace(/^v/, '');
            // Only use if it matches the latest npm version
            if (tagVer === latestVersion) {
              releaseNotes = release.body;
            }
          }
        } catch {}
      }

      // Trim excessively long notes
      if (releaseNotes.length > 1500) {
        releaseNotes = releaseNotes.substring(0, 1500) + '\n…(truncated)';
      }
    }

    const result = {
      checked_at: Date.now(),
      current_version: currentVersion,
      latest_version: latestVersion,
      has_update: hasUpdate,
      release_notes: releaseNotes,
    };

    writeCache(result);

    const msg = formatNotification(result);
    if (msg) process.stdout.write(msg + '\n');
  } catch {
    // Silent fail — never break session start
  }
}

main().then(() => process.exit(0)).catch(() => process.exit(0));
