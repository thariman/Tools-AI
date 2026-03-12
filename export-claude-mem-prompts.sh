#!/usr/bin/env bash
# Export all memories from claude-mem to JSON
# Usage:
#   ./export-claude-mem-prompts.sh [output_file] [port]        # via HTTP API (default)
#   ./export-claude-mem-prompts.sh --db [output_file] [db_path] # via SQLite directly

if [ "$1" = "--db" ]; then
  # SQLite mode
  OUTPUT="${2:-claude-mem-prompts.json}"
  DB="${3:-$HOME/.claude-mem/claude-mem.db}"

  if [ ! -f "$DB" ]; then
    echo "Error: Database not found at $DB" >&2
    exit 1
  fi

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
else
  # HTTP API mode (default)
  OUTPUT="${1:-all-memories.json}"
  PORT="${2:-37777}"
  URL="http://localhost:${PORT}/api/search?query=&format=json&limit=999999&dateStart=0"

  echo "Fetching all memories from claude-mem (port $PORT)..."

  if ! curl -sf "$URL" -o "$OUTPUT"; then
    echo "Error: Failed to fetch from $URL" >&2
    echo "Is claude-mem running on port $PORT?" >&2
    exit 1
  fi

  SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "Done: ($SIZE) -> $OUTPUT"
fi
