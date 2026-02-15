#!/usr/bin/env bash
# Session start hook: loads the root Pagelove skill into Claude Code context
# This script is called automatically when a new session starts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="$SCRIPT_DIR/../skills/using-pagelove/SKILL.md"

if [ -f "$SKILL_FILE" ]; then
    CONTENT=$(cat "$SKILL_FILE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "{\"context\": \"$CONTENT\"}"
else
    echo "{\"error\": \"Root skill file not found at $SKILL_FILE\"}"
fi
