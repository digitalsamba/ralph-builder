#!/bin/bash

#===============================================================================
# RALPH - Autonomous Agent Loop for Claude Code
#===============================================================================
#
#     "Me fail English? That's unpossible!"
#
#===============================================================================
# A bash loop that runs Claude Code iteratively with fresh context each time.
# Based on the "Ralph Wiggum" methodology for autonomous task completion.
#
# Usage:
#   ./ralph-builder/ralph.sh [OPTIONS]
#
# Options:
#   -d, --dir PATH         Project directory (default: current working directory)
#   -n, --iterations NUM   Max iterations (default: 100)
#   -m, --model MODEL      Claude model (sonnet, opus, haiku)
#   -t, --timeout SECS     Timeout per iteration in seconds (default: 1800)
#   -v, --verbose          Enable verbose output
#   --validate-only        Check setup without running loop
#   --cleanup              Kill orphaned Claude processes and exit
#   -h, --help             Show this help
#
# Required files in ralph-builder/:
#   - PROMPT.md              Instructions read each iteration
#   - plan.md                PRD with JSON task arrays
#   - activity.md            Progress log
#
# Required files in project root:
#   - CLAUDE.md              Project context
#   - .claude/settings.json  Tool permissions (see settings.template.json)
#
# Required permissions in .claude/settings.json:
#   - Bash(git add:*)
#   - Bash(git add -A)
#   - Bash(git add -A && git commit:*)  <- for combined commands
#   - Bash(git commit:*)  <- colon syntax required for multiline commits
#   - Read, Write, Edit, Glob, Grep
#
# Exit signals:
#   <promise>COMPLETE</promise>  - All tasks done, exit successfully
#   <promise>BLOCKED</promise>   - Agent stuck, needs human intervention
#
#===============================================================================

set -e

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

MAX_ITERATIONS=100
# BUILDER_DIR: where ralph.sh and generated files live (ralph-builder/)
BUILDER_DIR="$(cd "$(dirname "$0")" && pwd)"
# PROJECT_DIR: where user code lives (parent of ralph-builder/)
PROJECT_DIR="$(dirname "$BUILDER_DIR")"
VERBOSE=false
MODEL=""
VALIDATE_ONLY=false
CLEANUP_ONLY=false
ITERATION_TIMEOUT=1800  # 30 minutes default

# Process tracking
CLAUDE_PID=""
PROMPT_HASH=""

# Logging
LOG_DIR=""
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Ralph Wiggum quotes for different situations
RALPH_START=(
    "I'm helping!"
    "I'm learnding!"
    "Hi, Super Nintendo Chalmers!"
    "I found a moon rock in my nose!"
    "The leprechaun tells me to burn things!"
    "I bent my Wookie."
    "My cat's breath smells like cat food."
)

RALPH_SUCCESS=(
    "I'm a unitard!"
    "I won! I won!"
    "Me fail English? That's unpossible!"
    "When I grow up, I'm going to Bovine University!"
    "I'm Idaho!"
)

RALPH_ERROR=(
    "It tastes like burning."
    "My face is on fire!"
    "I eated the purple berries..."
    "Oww, my bones are so brittle!"
)

RALPH_COMPLETE=(
    "That's where I'm a viking!"
    "I'm a furniture!"
    "I dress myself!"
)

# Get random Ralph quote
ralph_quote() {
    local arr_name=$1
    case $arr_name in
        RALPH_START)   local arr=("${RALPH_START[@]}") ;;
        RALPH_SUCCESS) local arr=("${RALPH_SUCCESS[@]}") ;;
        RALPH_ERROR)   local arr=("${RALPH_ERROR[@]}") ;;
        RALPH_COMPLETE) local arr=("${RALPH_COMPLETE[@]}") ;;
    esac
    local count=${#arr[@]}
    if [ $count -gt 0 ]; then
        echo "${arr[$((RANDOM % count))]}"
    fi
}

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

show_help() {
    sed -n '1,/^#===.*===$/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 0
}

log() {
    local msg="[RALPH] $1"
    echo -e "${CYAN}${msg}${NC}"
    [ -n "$LOG_FILE" ] && echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

log_success() {
    local msg="[RALPH] $1"
    echo -e "${GREEN}${msg}${NC}"
    [ -n "$LOG_FILE" ] && echo "[$(date '+%H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

log_warn() {
    local msg="[RALPH] $1"
    echo -e "${YELLOW}${msg}${NC}"
    [ -n "$LOG_FILE" ] && echo "[$(date '+%H:%M:%S')] WARN: $1" >> "$LOG_FILE"
}

log_error() {
    local msg="[RALPH] $1"
    echo -e "${RED}${msg}${NC}"
    [ -n "$LOG_FILE" ] && echo "[$(date '+%H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

show_ralph() {
    echo -e "${CYAN}"
    cat << 'RALPH'
  ⠀⠀⠀⠀⠀⠀⣀⣤⣶⡶⢛⠟⡿⠻⢻⢿⢶⢦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  ⠀⠀⠀⢀⣠⡾⡫⢊⠌⡐⢡⠊⢰⠁⡎⠘⡄⢢⠙⡛⡷⢤⡀⠀⠀⠀⠀⠀⠀⠀
  ⠀⠀⢠⢪⢋⡞⢠⠃⡜⠀⠎⠀⠉⠀⠃⠀⠃⠀⠃⠙⠘⠊⢻⠦⠀⠀⠀⠀⠀⠀
  ⠀⠀⢇⡇⡜⠀⠜⠀⠁⠀⢀⠔⠉⠉⠑⠄⠀⠀⡰⠊⠉⠑⡄⡇⠀⠀⠀⠀⠀⠀
  ⠀⠀⡸⠧⠄⠀⠀⠀⠀⠀⠘⡀⠾⠀⠀⣸⠀⠀⢧⠀⠛⠀⠌⡇⠀⠀⠀⠀⠀⠀
  ⠀⠘⡇⠀⠀⠀⠀⠀⠀⠀⠀⠙⠒⠒⠚⠁⠈⠉⠲⡍⠒⠈⠀⡇⠀⠀⠀⠀⠀⠀
  ⠀⠀⠈⠲⣆⠀⠀⠀⠀⠀⠀⠀⠀⣠⠖⠉⡹⠤⠶⠁⠀⠀⠀⠈⢦⠀⠀⠀⠀⠀
  ⠀⠀⠀⠀⠈⣦⡀⠀⠀⠀⠀⠧⣴⠁⠀⠘⠓⢲⣄⣀⣀⣀⡤⠔⠃⠀⠀⠀⠀⠀
  ⠀⠀⠀⠀⣜⠀⠈⠓⠦⢄⣀⣀⣸⠀⠀⠀⠀⠁⢈⢇⣼⡁⠀⠀⠀⠀⠀⠀⠀⠀
  ⠀⠀⢠⠒⠛⠲⣄⠀⠀⠀⣠⠏⠀⠉⠲⣤⠀⢸⠋⢻⣤⡛⣄⠀⠀⠀⠀⠀⠀⠀
  ⠀⠀⢡⠀⠀⠀⠀⠉⢲⠾⠁⠀⠀⠀⠀⠈⢳⡾⣤⠟⠁⠹⣿⢆⠀⠀⠀⠀⠀⠀
  ⠀⢀⠼⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⠃⠀⠀⠀⠀⠀⠈⣧⠀⠀⠀⠀⠀
  ⠀⡏⠀⠘⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⠀⠀⠀⠀⠀⠀⢸⣧⠀⠀⠀⠀
  ⢰⣄⠀⠀⠀⠉⠳⠦⣤⣤⡤⠴⠖⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢯⣆⠀⠀⠀
  ⢸⣉⠉⠓⠲⢦⣤⣄⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣠⣼⢹⡄⠀⠀
  ⠘⡍⠙⠒⠶⢤⣄⣈⣉⡉⠉⠙⠛⠛⠛⠛⠛⠛⢻⠉⠉⠉⢙⣏⣁⣸⠇⡇⠀⠀
  ⠀⢣⠀⠀⠀⠀⠀⠀⠉⠉⠉⠙⠛⠛⠛⠛⠛⠛⠛⠒⠒⠒⠋⠉⠀⠸⠚⢇⠀⠀
  ⠀⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠇⢤⣨⠇⠀
  ⠀⠀⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣤⢻⡀⣸⠀⠀⠀
  ⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⠛⠉⠁⠀⠀⠀
  ⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⢠⢄⣀⣤⠤⠴⠒⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀
  ⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠘⡆⠀⠀⠀⠀⠀
  ⠀⠀⠀⡎⠀⠀⠀⠀⠀⠀⠀⠀⢷⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀
  ⠀⠀⢀⡷⢤⣤⣀⣀⣀⣀⣠⠤⠾⣤⣀⡘⠛⠶⠶⠶⠶⠖⠒⠋⠙⠓⠲⢤⣀⠀
  ⠀⠀⠘⠧⣀⡀⠈⠉⠉⠁⠀⠀⠀⠀⠈⠙⠳⣤⣄⣀⣀⣀⠀⠀⠀⠀⠀⢀⣈⡇
  ⠀⠀⠀⠀⠀⠉⠛⠲⠤⠤⢤⣤⣄⣀⣀⣀⣀⡸⠇⠀⠀⠀⠉⠉⠉⠉⠉⠉⠁⠀
RALPH
    echo -e "${NC}"
    echo -e "${YELLOW}   \"Me fail English? That's unpossible!\"${NC}"
    echo ""
    sleep 3
}

get_progress() {
    local completed=0
    local total=0

    if [ -f "$BUILDER_DIR/plan.md" ]; then
        # Count tasks with "passes": true
        completed=$(grep -c '"passes":\s*true' "$BUILDER_DIR/plan.md" 2>/dev/null || echo "0")
        # Count all tasks with "passes" field
        total=$(grep -c '"passes":' "$BUILDER_DIR/plan.md" 2>/dev/null || echo "0")
    fi

    # Ensure valid numbers
    [[ "$completed" =~ ^[0-9]+$ ]] || completed=0
    [[ "$total" =~ ^[0-9]+$ ]] || total=0

    if [ "$total" -eq 0 ]; then
        echo "0/0 (no tasks found)"
    else
        local percent=$((completed * 100 / total))
        echo "$completed/$total ($percent%)"
    fi
}

#-------------------------------------------------------------------------------
# Process Management
#-------------------------------------------------------------------------------

# Get hash of PROMPT.md to identify Ralph instances for this project
get_prompt_hash() {
    if [ -f "$BUILDER_DIR/PROMPT.md" ]; then
        md5 -q "$BUILDER_DIR/PROMPT.md" 2>/dev/null || md5sum "$BUILDER_DIR/PROMPT.md" 2>/dev/null | cut -d' ' -f1 || echo "unknown"
    else
        echo "unknown"
    fi
}

# Kill a specific Claude process
kill_claude_process() {
    local pid=$1
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log_warn "Killing Claude process $pid..."
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null
        fi
    fi
}

# Kill all orphaned Claude processes from previous Ralph runs
cleanup_orphaned_processes() {
    local count=0

    # Find Claude processes running with -p flag (Ralph instances)
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local started=$(echo "$line" | awk '{print $9}')

        # Skip if it's our current session's process
        if [ "$pid" != "$$" ] && [ -n "$pid" ]; then
            log_warn "Found orphaned Claude process: PID $pid (started $started)"
            kill_claude_process "$pid"
            ((count++))
        fi
    done < <(ps aux | grep "claude -p" | grep -v grep | grep -v "$$")

    if [ $count -gt 0 ]; then
        log_success "Cleaned up $count orphaned process(es)"
    fi

    return $count
}

# Kill current iteration's Claude process
kill_current_claude() {
    if [ -n "$CLAUDE_PID" ]; then
        kill_claude_process "$CLAUDE_PID"
        CLAUDE_PID=""
    fi
}

#-------------------------------------------------------------------------------
# Validation
#-------------------------------------------------------------------------------

validate_setup() {
    local errors=0
    local warnings=0

    log "Validating project setup..."
    echo ""

    # Required files in ralph-builder/
    local required_files=("PROMPT.md" "plan.md" "activity.md")
    for file in "${required_files[@]}"; do
        if [ -f "$BUILDER_DIR/$file" ]; then
            echo -e "  ${GREEN}✓${NC} ralph-builder/$file"
        else
            echo -e "  ${RED}✗${NC} ralph-builder/$file (missing)"
            ((errors++))
        fi
    done

    # CLAUDE.md at project root
    if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
        echo -e "  ${GREEN}✓${NC} CLAUDE.md"
    else
        echo -e "  ${RED}✗${NC} CLAUDE.md (missing)"
        ((errors++))
    fi

    # Settings file at project root
    if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
        echo -e "  ${GREEN}✓${NC} .claude/settings.json"

        # Check for minimum permissions
        if grep -q '"allow"' "$PROJECT_DIR/.claude/settings.json"; then
            echo -e "  ${GREEN}✓${NC} Permissions configured"
        else
            echo -e "  ${YELLOW}!${NC} No 'allow' permissions found in settings.json"
            ((warnings++))
        fi
    else
        echo -e "  ${RED}✗${NC} .claude/settings.json (missing)"
        ((errors++))
    fi

    # Optional but recommended
    echo ""
    if [ -f "$PROJECT_DIR/.env" ]; then
        echo -e "  ${GREEN}✓${NC} .env file present"
    else
        echo -e "  ${YELLOW}!${NC} .env file not found (optional)"
    fi

    # Check plan.md has tasks
    if [ -f "$BUILDER_DIR/plan.md" ]; then
        local task_count=$(grep -c '"passes":' "$BUILDER_DIR/plan.md" 2>/dev/null || echo "0")
        if [ "$task_count" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} plan.md has $task_count tasks"
        else
            echo -e "  ${YELLOW}!${NC} plan.md has no tasks defined"
            ((warnings++))
        fi
    fi

    echo ""

    if [ $errors -gt 0 ]; then
        log_error "Validation failed with $errors error(s)"
        log_error "Run setup first: Ask Claude 'Help me set up this project using Ralph Builder'"
        return 1
    elif [ $warnings -gt 0 ]; then
        log_warn "Validation passed with $warnings warning(s)"
        return 0
    else
        log_success "Validation passed"
        return 0
    fi
}

#-------------------------------------------------------------------------------
# Parse Arguments
#-------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            PROJECT_DIR="$(cd "$2" && pwd)"
            shift 2
            ;;
        -n|--iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -t|--timeout)
            ITERATION_TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

#-------------------------------------------------------------------------------
# Setup
#-------------------------------------------------------------------------------

# Initialize logging
LOG_DIR="$BUILDER_DIR/.ralph-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ralph-$TIMESTAMP.log"

# Handle cleanup-only mode
if [ "$CLEANUP_ONLY" = true ]; then
    log "Running cleanup mode..."
    cleanup_orphaned_processes
    log "Cleanup complete"
    exit 0
fi

# Show banner
show_ralph

log "Project: $PROJECT_DIR"
log "Builder: $BUILDER_DIR"
log "Max iterations: $MAX_ITERATIONS"
log "Iteration timeout: ${ITERATION_TIMEOUT}s"
[ -n "$MODEL" ] && log "Model: $MODEL"
log "Log file: $LOG_FILE"
echo ""

# Clean up any orphaned processes from previous runs
log "Checking for orphaned processes..."
cleanup_orphaned_processes
echo ""

# Validate setup
if ! validate_setup; then
    exit 1
fi

# Exit if validate-only
if [ "$VALIDATE_ONLY" = true ]; then
    exit 0
fi

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    log "Loading .env..."
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Build Claude command
CLAUDE_CMD="claude"

if [ "$VERBOSE" = true ]; then
    CLAUDE_CMD="$CLAUDE_CMD --verbose"
fi

if [ -n "$MODEL" ]; then
    CLAUDE_CMD="$CLAUDE_CMD --model $MODEL"
fi

# Store prompt hash for process identification
PROMPT_HASH=$(get_prompt_hash)

#-------------------------------------------------------------------------------
# Signal Handling
#-------------------------------------------------------------------------------

cleanup() {
    echo ""
    log_warn "Interrupted - cleaning up..."

    # Kill current Claude process
    kill_current_claude

    # Clean up temp files
    rm -f "/tmp/ralph-output-$$.txt"

    log "Progress: $(get_progress)"
    log "Log saved: $LOG_FILE"
    exit 130
}

trap cleanup SIGINT SIGTERM EXIT

#-------------------------------------------------------------------------------
# Main Loop
#-------------------------------------------------------------------------------

echo ""
log "=========================================="
log "Starting autonomous loop"
log "=========================================="
echo ""

ITERATION=0
START_TIME=$(date +%s)

cd "$PROJECT_DIR"

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))
    ITER_START=$(date +%s)

    echo ""
    log "────────────────────────────────────────"
    log "Iteration $ITERATION of $MAX_ITERATIONS"
    log "Progress: $(get_progress)"
    log "Time: $(date '+%H:%M:%S')"
    echo -e "    ${YELLOW}💬 \"$(ralph_quote RALPH_START)\"${NC}"
    log "────────────────────────────────────────"
    echo ""

    # Run Claude with stream-json for real-time visibility
    OUTPUT_FILE="/tmp/ralph-output-$$.json"

    log "Running Claude..."
    echo ""

    # Stream JSON output: tee saves raw JSON, jq extracts readable text in real-time
    # Colors: \u001b[36m=cyan, \u001b[32m=green, \u001b[33m=yellow, \u001b[0m=reset
    $CLAUDE_CMD -p "$(cat "$BUILDER_DIR/PROMPT.md")" --output-format stream-json --verbose 2>&1 \
        | tee "$OUTPUT_FILE" \
        | jq -r --unbuffered '
            # Tool calls - cyan
            if .type == "assistant" and (.message.content[]? | .type == "tool_use") then
                .message.content[] | select(.type == "tool_use") |
                "\u001b[36m⚡ " + .name + "\u001b[0m" +
                (if .input.file_path then " → " + (.input.file_path | split("/") | last)
                 elif .input.command then " → " + (.input.command | split("\n")[0] | .[0:60])
                 elif .input.pattern then " → " + .input.pattern
                 else "" end)
            # Assistant text - default color
            elif .type == "assistant" then
                .message.content[]? | select(.type == "text") | .text // empty
            # Result summary - green
            elif .type == "result" then
                "\n\u001b[32m✓ Done: " + (.duration_ms / 1000 | floor | tostring) + "s, " +
                (.num_turns | tostring) + " turns, $" +
                ((.total_cost_usd * 100 | floor) / 100 | tostring) + "\u001b[0m"
            else
                empty
            end
        ' 2>/dev/null

    EXIT_CODE=${PIPESTATUS[0]}

    echo ""

    if [ $EXIT_CODE -ne 0 ]; then
        log_warn "Claude exited with code $EXIT_CODE"
    fi

    # Check for completion signal
    if grep -q "<promise>COMPLETE</promise>" "$OUTPUT_FILE" 2>/dev/null; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo ""
        log_success "=========================================="
        log_success "COMPLETE!"
        echo -e "    ${YELLOW}💬 \"$(ralph_quote RALPH_COMPLETE)\"${NC}"
        log_success "=========================================="
        log_success "Finished at iteration $ITERATION"
        log_success "Total time: $((ELAPSED / 60))m $((ELAPSED % 60))s"
        log_success "Final progress: $(get_progress)"
        log_success "(Progress includes backlog items if present)"
        log_success "=========================================="
        rm -f "$OUTPUT_FILE"
        trap - EXIT  # Remove exit trap for clean exit
        exit 0
    fi

    # Check for blocked signal
    if grep -q "<promise>BLOCKED</promise>" "$OUTPUT_FILE" 2>/dev/null; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo ""
        log_error "=========================================="
        log_error "BLOCKED - Human intervention required"
        echo -e "    ${YELLOW}💬 \"$(ralph_quote RALPH_ERROR)\"${NC}"
        log_error "=========================================="
        log_error "Stopped at iteration $ITERATION"
        log_error "Total time: $((ELAPSED / 60))m $((ELAPSED % 60))s"
        log_error "Progress: $(get_progress)"
        log_error "(Progress includes backlog items if present)"
        log_error ""
        log_error "The agent is stuck and needs help."
        log_error "Check activity.md for details on the blocker."
        log_error "Open a new Claude session to investigate."
        log_error "=========================================="
        rm -f "$OUTPUT_FILE"
        trap - EXIT
        exit 1
    fi

    rm -f "$OUTPUT_FILE"

    # Iteration timing
    ITER_ELAPSED=$(($(date +%s) - ITER_START))
    log "Iteration completed in ${ITER_ELAPSED}s"
    echo -e "    ${GREEN}💬 \"$(ralph_quote RALPH_SUCCESS)\"${NC}"

    # Brief pause between iterations
    sleep 2
done

#-------------------------------------------------------------------------------
# Max Iterations Reached
#-------------------------------------------------------------------------------

ELAPSED=$(($(date +%s) - START_TIME))
echo ""
log_warn "=========================================="
log_warn "MAX ITERATIONS REACHED"
log_warn "=========================================="
log_warn "Completed $MAX_ITERATIONS iterations without finishing"
log_warn "Total time: $((ELAPSED / 60))m $((ELAPSED % 60))s"
log_warn "Progress: $(get_progress)"
log_warn ""
log_warn "Options:"
log_warn "  1. Run again with more iterations: ./ralph-builder/ralph.sh -n 200"
log_warn "  2. Check activity.md for progress"
log_warn "  3. Open Claude to investigate"
log_warn "=========================================="

trap - EXIT
exit 0
