#!/usr/bin/env bash
#
# should-dream.sh - Check if dream consolidation should run
#
# Returns exit code 0 if dream should run, 1 if not.
# Condition: 24+ hours since last consolidation.
#
# Reads memory type from ~/.claude/skills/dream/.dream-config
# Supports: native (Claude Code auto-memory), openclaw, project-root

set -euo pipefail

SKILL_DIR="$HOME/.claude/skills/dream"
CONFIG="$SKILL_DIR/.dream-config"

# Read config or default to native
DREAM_MEMORY_TYPE="native"
if [[ -f "$CONFIG" ]]; then
    DREAM_MEMORY_TYPE=$(grep '^DREAM_MEMORY_TYPE=' "$CONFIG" | cut -d= -f2 || echo "native")
fi

# Find the .last-dream timestamp based on memory type
LAST_DREAM=0
case "$DREAM_MEMORY_TYPE" in
    native)
        # Find the most recent .last-dream timestamp across all projects
        NEWEST_TIMESTAMP=0
        for dir in "$HOME/.claude/projects/"*/memory/; do
            if [[ -f "$dir/.last-dream" ]]; then
                TS=$(cat "$dir/.last-dream" 2>/dev/null || echo 0)
                if [[ "$TS" =~ ^[0-9]+$ ]]; then
                    if (( TS > NEWEST_TIMESTAMP )); then
                        NEWEST_TIMESTAMP=$TS
                    fi
                fi
            fi
        done
        # If no .last-dream found anywhere, dream has never run - condition met
        if (( NEWEST_TIMESTAMP == 0 )); then
            echo "Dream conditions met: first-run (no .last-dream found)"
            exit 0
        fi
        LAST_DREAM=$NEWEST_TIMESTAMP
        ;;
    openclaw|project-root)
        DREAM_MEMORY_PATH=$(grep '^DREAM_MEMORY_PATH=' "$CONFIG" | cut -d= -f2 || echo ".")
        DREAM_MEMORY_PATH="${DREAM_MEMORY_PATH/#\~/$HOME}"
        LAST_DREAM_FILE="$DREAM_MEMORY_PATH/.last-dream"
        if [[ ! -f "$LAST_DREAM_FILE" ]]; then
            echo "Dream conditions met: first-run"
            exit 0
        fi
        LAST_DREAM=$(cat "$LAST_DREAM_FILE")
        ;;
esac
NOW=$(date +%s)
ELAPSED=$(( NOW - LAST_DREAM ))
HOURS_ELAPSED=$(( ELAPSED / 3600 ))

if (( HOURS_ELAPSED < 24 )); then
    exit 1  # Too soon
fi

echo "Dream conditions met: ${HOURS_ELAPSED}h since last dream"
exit 0
