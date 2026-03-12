#!/usr/bin/env bash
# Export memories from claude-mem to JSON
# Usage:
#   ./export-claude-mem-prompts.sh [output_file] [port]                 # full memories via HTTP API (default)
#   ./export-claude-mem-prompts.sh --prompts-only [output_file] [port]  # user prompts only via HTTP API
#   ./export-claude-mem-prompts.sh --db [output_file] [db_path]         # full memories via SQLite
#   ./export-claude-mem-prompts.sh --db --prompts-only [output_file] [db_path] # user prompts only via SQLite

# Parse flags
USE_DB=false
PROMPTS_ONLY=false
while [[ "$1" == --* ]]; do
  case "$1" in
    --db) USE_DB=true; shift ;;
    --prompts-only) PROMPTS_ONLY=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if $USE_DB; then
  # SQLite mode
  OUTPUT="${1:-claude-mem-prompts.json}"
  DB="${2:-$HOME/.claude-mem/claude-mem.db}"

  if [ ! -f "$DB" ]; then
    echo "Error: Database not found at $DB" >&2
    exit 1
  fi

  if $PROMPTS_ONLY; then
    COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM user_prompts;")
    echo "Exporting $COUNT prompts from $DB..."

    sqlite3 "$DB" "SELECT json_group_array(json_object(
      'id', id,
      'content_session_id', content_session_id,
      'prompt_number', prompt_number,
      'prompt_text', prompt_text,
      'created_at', created_at,
      'created_at_epoch', created_at_epoch
    )) FROM user_prompts ORDER BY id ASC;" > "$OUTPUT"

    SIZE=$(du -h "$OUTPUT" | cut -f1)
    echo "Done: $COUNT prompts ($SIZE) -> $OUTPUT"
  else
    OBS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM observations;")
    SESS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM session_summaries;")
    PROMPTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM user_prompts;")
    echo "Exporting from $DB: $OBS observations, $SESS sessions, $PROMPTS prompts..."

    sqlite3 "$DB" "SELECT json_object(
      'observations', (SELECT json_group_array(json_object(
        'id', id,
        'memory_session_id', memory_session_id,
        'project', project,
        'text', text,
        'type', type,
        'title', title,
        'subtitle', subtitle,
        'facts', facts,
        'narrative', narrative,
        'concepts', concepts,
        'files_read', files_read,
        'files_modified', files_modified,
        'prompt_number', prompt_number,
        'created_at', created_at,
        'created_at_epoch', created_at_epoch,
        'content_hash', content_hash,
        'discovery_tokens', discovery_tokens
      )) FROM observations ORDER BY id ASC),
      'sessions', (SELECT json_group_array(json_object(
        'id', id,
        'memory_session_id', memory_session_id,
        'project', project,
        'request', request,
        'investigated', investigated,
        'learned', learned,
        'completed', completed,
        'next_steps', next_steps,
        'files_read', files_read,
        'files_edited', files_edited,
        'notes', notes,
        'prompt_number', prompt_number,
        'created_at', created_at,
        'created_at_epoch', created_at_epoch,
        'discovery_tokens', discovery_tokens
      )) FROM session_summaries ORDER BY id ASC),
      'prompts', (SELECT json_group_array(json_object(
        'id', id,
        'content_session_id', content_session_id,
        'prompt_number', prompt_number,
        'prompt_text', prompt_text,
        'created_at', created_at,
        'created_at_epoch', created_at_epoch
      )) FROM user_prompts ORDER BY id ASC),
      'totalResults', (SELECT COUNT(*) FROM observations) + (SELECT COUNT(*) FROM session_summaries) + (SELECT COUNT(*) FROM user_prompts)
    );" > "$OUTPUT"

    SIZE=$(du -h "$OUTPUT" | cut -f1)
    TOTAL=$((OBS + SESS + PROMPTS))
    echo "Done: $TOTAL records ($SIZE) -> $OUTPUT"
  fi
else
  # HTTP API mode (default)
  OUTPUT="${1:-all-memories.json}"
  PORT="${2:-37777}"

  URL="http://localhost:${PORT}/api/search?query=&format=json&limit=999999&dateStart=0"

  if $PROMPTS_ONLY; then
    echo "Fetching user prompts from claude-mem (port $PORT)..."
  else
    echo "Fetching all memories from claude-mem (port $PORT)..."
  fi

  if ! curl -sf "$URL" -o "$OUTPUT.tmp"; then
    echo "Error: Failed to fetch from $URL" >&2
    echo "Is claude-mem running on port $PORT?" >&2
    rm -f "$OUTPUT.tmp"
    exit 1
  fi

  if $PROMPTS_ONLY; then
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); json.dump(d.get('prompts',[]),open(sys.argv[2],'w'))" "$OUTPUT.tmp" "$OUTPUT"
    rm -f "$OUTPUT.tmp"
  else
    mv "$OUTPUT.tmp" "$OUTPUT"
  fi

  SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "Done: ($SIZE) -> $OUTPUT"
fi
