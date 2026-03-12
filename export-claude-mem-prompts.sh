#!/usr/bin/env bash
# Export all user prompts from claude-mem SQLite database to JSON
# Usage: ./export-claude-mem-prompts.sh [output_file] [db_path]

OUTPUT="${1:-claude-mem-prompts.json}"
DB="${2:-$HOME/.claude-mem/claude-mem.db}"

if [ ! -f "$DB" ]; then
  echo "Error: Database not found at $DB" >&2
  exit 1
fi

COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM user_prompts;")
echo "Exporting $COUNT prompts from $DB..."

sqlite3 "$DB" "SELECT json_group_array(json_object(
  'id', id,
  'session_id', content_session_id,
  'prompt_number', prompt_number,
  'prompt_text', prompt_text,
  'created_at', created_at,
  'created_at_epoch', created_at_epoch
)) FROM user_prompts ORDER BY id ASC;" > "$OUTPUT"

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Done: $COUNT prompts ($SIZE) -> $OUTPUT"
